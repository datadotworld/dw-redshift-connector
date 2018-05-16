WORKING_DIR=/tmp
STATE=state
CATALOG_FILE=catalog.json
CATALOG_PATH=${WORKING_DIR}/${CATALOG_FILE}
LATEST_STATE_PATH=${WORKING_DIR}/latest-state.json

DW_CONFIG_PATH=${WORKING_DIR}/config-dw.json
REDSHIFT_CONFIG_PATH=${WORKING_DIR}/config-redshift.json

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
	echo "$${DW_CONFIG_BODY}" > ${DW_CONFIG_PATH}
	echo "$${REDSHIFT_CONFIG_BODY}" > ${REDSHIFT_CONFIG_PATH}

catalog-discovery: prep-config-files
	tap-redshift -c ${REDSHIFT_CONFIG_PATH} -d > ${CATALOG_PATH}
	python utils/prep_catalog.py -c ${CATALOG_PATH}

fetch-catalog:
	@curl --get \
		--header "Authorization: Bearer ${DW_TOKEN}" \
		--output "${CATALOG_PATH}" \
		--url "${BASE_URL}/file_download/${DW_DATASET_SLUG}/${CATALOG_FILE}"

fetch-latest-state:
	@curl --get \
		--header "Authorization: Bearer ${DW_TOKEN}" \
		--header "Accept: text/csv" \
		--output "${LATEST_STATE_PATH}" \
		--url "${BASE_URL}/sql/${DW_DATASET_SLUG}" \
		--data-urlencode "query=SELECT * FROM state ORDER BY date_column DESC LIMIT 1"

push-catalog: catalog-discovery
	@curl --request PUT \
		--header "Authorization: Bearer ${DW_TOKEN}" \
		--header "Content-Type: application/octet-stream" \
		--url "${BASE_URL}/uploads/${DW_DATASET_SLUG}/files/${CATALOG_FILE}" \
		--data-binary @${CATALOG_PATH}

append-state:
	@curl --request POST \
		--header "Authorization: Bearer ${DW_TOKEN}" \
		--header "Content-Type: application/json" \
		--url "${BASE_URL}/streams/${DW_DATASET_SLUG}/${STATE}" \
		--data-binary @${LATEST_STATE_PATH}
	@sleep 3
	@curl --get \
		--header "Authorization: Bearer ${DW_TOKEN}" \
		--url "${BASE_URL}/datasets/${DW_DATASET_SLUG}/sync"

full-sync: push-catalog
	tap-redshift -c ${REDSHIFT_CONFIG_PATH} --catalog ${CATALOG_PATH} \
		| target-datadotworld -c ${DW_CONFIG_PATH} > ${LATEST_STATE_PATH}

incremental-sync: fetch-catalog fetch-latest-state
	tap-redshift -c ${REDSHIFT_CONFIG_PATH} --catalog ${CATALOG_PATH} -s ${LATEST_STATE_PATH} \
		| target-datadotworld -c ${DW_CONFIG_PATH} > ${LATEST_STATE_PATH}

fetch-all:
	$(MAKE) full-sync
	$(MAKE) append-state

update:
	$(MAKE) incremental-sync
	$(MAKE) append-state
