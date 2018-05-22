BASE_URL=https://api.data.world/v0

WORKING_DIR=/tmp

DW_DATASET_SLUG=${DW_DATASET_OWNER}/${DW_DATASET_ID}
DW_DATASET_ADMIN_SLUG=${DW_DATASET_OWNER}/${DW_DATASET_ID_ADMIN}

CATALOG_FILE=catalog-${DW_DATASET_ID}
CATALOG_FILE_CSV=${CATALOG_FILE}.csv
CATALOG_PATH=${WORKING_DIR}/${CATALOG_FILE}
CATALOG_PATH_CSV=${WORKING_DIR}/${CATALOG_FILE_CSV}
CATALOG_PATH_JSON=${WORKING_DIR}/${CATALOG_FILE}.json

STATE=state-${DW_DATASET_ID}
STATE_PATH=${WORKING_DIR}/${STATE}.jsonl
NEW_STATE_PATH=${WORKING_DIR}/new-${STATE}.json
LATEST_STATE_PATH=${WORKING_DIR}/latest-${STATE}.json

DW_CONFIG_PATH=${WORKING_DIR}/config-dw.json
REDSHIFT_CONFIG_PATH=${WORKING_DIR}/config-redshift.json

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
	echo "$${DW_CONFIG_BODY}" > ${DW_CONFIG_PATH}
	echo "$${REDSHIFT_CONFIG_BODY}" > ${REDSHIFT_CONFIG_PATH}

catalog-discovery: prep-singer-config-files
	tap-redshift --discover --config ${REDSHIFT_CONFIG_PATH} > ${CATALOG_PATH_JSON}

prep-catalog-config: catalog-discovery
	python utils/prep_catalog_config.py --catalog ${CATALOG_PATH}

fetch-catalog-config:
	@curl --get \
		--header "Authorization: Bearer ${DW_TOKEN}" \
		--output "${CATALOG_PATH_CSV}" \
		--url "${BASE_URL}/file_download/${DW_DATASET_SLUG}/${CATALOG_FILE_CSV}"

parse-catalog-config: catalog-discovery fetch-catalog-config
	python utils/parse_catalog_config.py --catalog ${CATALOG_PATH_JSON} --config ${CATALOG_PATH_CSV}

fetch-latest-state:
	if curl --get --fail \
		--header "Authorization: Bearer ${DW_TOKEN}" \
		--output "${STATE_PATH}" \
		--url "${BASE_URL}/file_download/${DW_DATASET_SLUG}/${STATE}.jsonl"; then \
		tail -1 ${STATE_PATH} > ${LATEST_STATE_PATH}; \
	fi

push-catalog-config: prep-catalog-config
	@curl --request PUT \
		--header "Authorization: Bearer ${DW_TOKEN}" \
		--header "Content-Type: application/octet-stream" \
		--url "${BASE_URL}/uploads/${DW_DATASET_SLUG}/files/${CATALOG_FILE_CSV}" \
		--data-binary @${CATALOG_PATH_CSV}

append-state:
	@curl --request POST \
		--header "Authorization: Bearer ${DW_TOKEN}" \
		--header "Content-Type: application/json" \
		--url "${BASE_URL}/streams/${DW_DATASET_SLUG}/${STATE}" \
		--data-binary @${NEW_STATE_PATH}
	@sleep 3
	@curl --get \
		--header "Authorization: Bearer ${DW_TOKEN}" \
		--url "${BASE_URL}/datasets/${DW_DATASET_SLUG}/sync"

full-sync: parse-catalog-config
	tap-redshift --config ${REDSHIFT_CONFIG_PATH} --catalog ${CATALOG_PATH_JSON} \
		| target-datadotworld --config ${DW_CONFIG_PATH} > ${NEW_STATE_PATH}

sync: parse-catalog-config fetch-latest-state
	tap-redshift --config ${REDSHIFT_CONFIG_PATH} --catalog ${CATALOG_PATH_JSON} --state ${LATEST_STATE_PATH} \
		| target-datadotworld --config ${DW_CONFIG_PATH} > ${NEW_STATE_PATH}

fetch-all:
	$(MAKE) full-sync
	$(MAKE) append-state

incremental-update:
	$(MAKE) sync
	$(MAKE) append-state

update: fetch-latest-state
	if [ -f ${LATEST_STATE_PATH} ]; then \
		$(MAKE) incremental-update; \
	else \
		$(MAKE) fetch-all; \
	fi
