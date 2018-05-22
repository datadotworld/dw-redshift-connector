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

parser = argparse.ArgumentParser(description='Prepares a catalog configuration file to be manually edited.')
parser.add_argument('--catalog', required=True, help='path to the catalog file')

args = parser.parse_args()
with open(f'{args.catalog}.json') as f:
    catalog = json.load(f)

tables = []
for stream in catalog['streams']:
    schema, table_name = stream['table_name'].split('.')

    tables.append({
        'schema': schema,
        'table_name': table_name,
        'selected': '',
    })

with open(f'{args.catalog}.csv', 'w') as f:
    c = csv.DictWriter(f, fieldnames=tables[0].keys())

    c.writeheader()
    c.writerows(tables)
