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
import requests

parser = argparse.ArgumentParser(description='Prepares a catalog file to be used with Singer targets.')
parser.add_argument('--config', required=True, help='path to the catalog config file')
parser.add_argument('--dataset', required=True, help='path to the catalog config file')
parser.add_argument('--token', required=True, help='data.world api token')

args = parser.parse_args()
with open(args.config) as f_config:
    config = list(csv.DictReader(f_config))


def delete_file(name):
    headers = {
        'Authorization': f'Bearer {args.token}',
    }
    url = f'https://api.data.world/v0/datasets/{args.dataset}/files/{name}'
    requests.delete(url, headers=headers)


for table in config:
    if table['selected'] == '*':
        delete_file(f"{table['table_name']}.jsonl")
