WORKING_DIR=/tmp
CATALOG_FILE=${WORKING_DIR}/catalog.json
LATEST_STATE=latest-state
LATEST_STATE_FILE=${WORKING_DIR}/${LATEST_STATE}.json

DW_CONFIG_FILE=${WORKING_DIR}/config-dw.json
REDSHIFT_CONFIG_FILE=${WORKING_DIR}/config-redshift.json

BASE_URL=https://api.data.world/v0

DW_DATASET_SLUG=${DW_DATASET_OWNER}/${DW_DATASET_ID}

define DW_CONFIG_BODY
{
  "api_token": "${DW_TOKEN}",
  "dataset_owner": "${DW_DATASET_OWNER}",
  "dataset_id": "${DW_DATASET_ID}"
}
endef
export DW_CONFIG_BODY

define REDSHIFT_CONFIG_BODY
{
  "host": "${REDSHIFT_HOST}",
  "port": "${REDSHIFT_PORT}",
  "dbname": "${REDSHIFT_DBNAME}",
  "user": "${REDSHIFT_USER}",
  "password": "${REDSHIFT_PASSWORD}"
}
endef
export REDSHIFT_CONFIG_BODY

prep-config-files:
	echo "$${DW_CONFIG_BODY}" > ${DW_CONFIG_FILE}
	echo "$${REDSHIFT_CONFIG_BODY}" > ${REDSHIFT_CONFIG_FILE}

catalog-discovery: prep-config-files
	tap-redshift -c ${REDSHIFT_CONFIG_FILE} -d > ${CATALOG_FILE}
	python utils/prep_catalog.py -c ${CATALOG_FILE}

fetch-catalog:
	@curl --get \
		--header "Authorization: Bearer ${DW_TOKEN}" \
		--header "Accept: text/csv" \
		--url "${BASE_URL}/sql/${DW_DATASET_SLUG}" \
		--data-urlencode "query=SELECT * FROM table ORDER BY date_column DESC LIMIT 1"

fetch-latest-state:
	@curl --get \
		--header "Authorization: Bearer ${DW_TOKEN}" \
		--header "Accept: text/csv" \
		--url "${BASE_URL}/sql/${DW_DATASET_SLUG}" \
		--data-urlencode "query=SELECT * FROM table ORDER BY date_column DESC LIMIT 1"

push-catalog: catalog-discovery
	@curl --request POST \
		--header "Authorization: Bearer ${DW_TOKEN}" \
		--header "Content-Type: application/json" \
		--url "${BASE_URL}/streams/${DW_DATASET_SLUG}/${LATEST_STATE}" \
		--data-binary @${CATALOG_FILE}

append-state:
	@curl --request POST \
		--header "Authorization: Bearer ${DW_TOKEN}" \
		--header "Content-Type: application/json" \
		--url "${BASE_URL}/streams/${DW_DATASET_SLUG}/${LATEST_STATE}" \
		--data-binary @${LATEST_STATE_FILE}
	@sleep 3
	@curl --get \
		--header "Authorization: Bearer ${DW_TOKEN}" \
		--url "${BASE_URL}/datasets/${DW_DATASET_SLUG}/sync"

full-sync: push-catalog
	tap-redshift -c ${REDSHIFT_CONFIG_FILE} --catalog ${CATALOG_FILE} \
		| target-datadotworld -c ${DW_CONFIG_FILE} > ${LATEST_STATE_FILE}

incremental-sync: fetch-catalog fetch-latest-state
	tap-redshift -c ${REDSHIFT_CONFIG_FILE} --catalog ${CATALOG_FILE} -s ${LATEST_STATE_FILE} \
		| target-datadotworld -c ${DW_CONFIG_FILE} > ${LATEST_STATE_FILE}

fetch-all:
	$(MAKE) full-sync
	$(MAKE) append-state

update:
	$(MAKE) incremental-sync
	$(MAKE) append-state
