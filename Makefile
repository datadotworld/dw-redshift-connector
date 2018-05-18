BASE_URL=https://api.data.world/v0

WORKING_DIR=/tmp

CATALOG_FILE=catalog
CATALOG_PATH=${WORKING_DIR}/${CATALOG_FILE}
CATALOG_PATH_CSV=${WORKING_DIR}/${CATALOG_FILE}.csv
CATALOG_PATH_JSON=${WORKING_DIR}/${CATALOG_FILE}.json

LATEST_STATE_PATH=${WORKING_DIR}/latest-state.json
STATE=state

DW_CONFIG_FULL_PATH=${WORKING_DIR}/config-dw.json
REDSHIFT_CONFIG_FULL_PATH=${WORKING_DIR}/config-redshift.json

DW_DATASET_SLUG=${DW_DATASET_OWNER}/${DW_DATASET_ID}
DW_DATASET_ADMIN_SLUG=${DW_DATASET_OWNER}/${DW_DATASET_ID_ADMIN}

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

prep-singer-config-files:
	echo "$${DW_CONFIG_BODY}" > ${DW_CONFIG_FULL_PATH}
	echo "$${REDSHIFT_CONFIG_BODY}" > ${REDSHIFT_CONFIG_FULL_PATH}

catalog-discovery: prep-singer-config-files
	tap-redshift --config ${REDSHIFT_CONFIG_FULL_PATH} --discovery > ${CATALOG_PATH_JSON}

prep-catalog-config: catalog-discovery
	python utils/prep_catalog_config.py --catalog ${CATALOG_PATH}

# TODO pull catalog-dataset-id
fetch-catalog:
	@curl --get \
		--header "Authorization: Bearer ${DW_TOKEN}" \
		--header "Accept: text/csv" \
		--output "${CATALOG_PATH_CSV}" \
		--url "${BASE_URL}/sql/${DW_DATASET_SLUG}" \
        --data-urlencode "query=SELECT * FROM "

fetch-latest-state:
	@curl --get \
		--header "Authorization: Bearer ${DW_TOKEN}" \
		--header "Accept: text/csv" \
		--output "${LATEST_STATE_PATH}" \
		--url "${BASE_URL}/sql/${DW_DATASET_SLUG}" \
		--data-urlencode "query=SELECT * FROM state ORDER BY date_column DESC LIMIT 1"

push-catalog: prep-catalog-config
	@curl --request PUT \
		--header "Authorization: Bearer ${DW_TOKEN}" \
		--header "Content-Type: application/octet-stream" \
		--url "${BASE_URL}/uploads/${DW_DATASET_SLUG}/files/${CATALOG_FILE}" \
		--data-binary @${CATALOG_PATH_CSV}

# TODO push state-dataset-id
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

full-sync:
	tap-redshift --config ${REDSHIFT_CONFIG_FULL_PATH} --catalog ${CATALOG_PATH_JSON} \
		| target-datadotworld --config ${DW_CONFIG_FULL_PATH}

sync:
	tap-redshift --config ${REDSHIFT_CONFIG_FULL_PATH} --catalog ${CATALOG_PATH_JSON} --state ${LATEST_STATE_PATH} \
		| target-datadotworld --config ${DW_CONFIG_FULL_PATH} > ${LATEST_STATE_PATH}

fetch-all:
	$(MAKE) full-sync
	$(MAKE) append-state

update:
	$(MAKE) sync
	$(MAKE) append-state
