# dw-redshift-connector
# Copyright 2018 data.world, Inc.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the
# License.
#
# You may obtain a copy of the License at
# http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or
# implied. See the License for the specific language governing
# permissions and limitations under the License.
#
# This product includes software developed at
# data.world, Inc.(http://data.world/).

import argparse
import csv
import json

parser = argparse.ArgumentParser(description='Prepares a catalog file to be used with singer targets.')
parser.add_argument('--catalog', required=True, help='path to the catalog file')
parser.add_argument('--config', required=True, help='path to the catalog config file')

args = parser.parse_args()
with open(f'{args.catalog}.json') as f_catalog, open(f'{args.config}.csv') as f_config:
    catalog = json.load(f_catalog)
    config = list(csv.DictReader(f_config))

# Activate selected streams
for stream in catalog['streams']:
    for entry in stream['metadata']:
        if not entry['breadcrumb']:
            entry['metadata']['selected'] = True

with open(f'{args.catalog}-full.json', 'w') as f:
    contents = json.dumps(catalog)
    f.write(contents)
