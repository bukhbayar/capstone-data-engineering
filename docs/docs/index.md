# capstone-data-engineering documentation!

## Description

capstone project

## Commands

The Makefile contains the central entry points for common tasks related to this project.

### Syncing data to cloud storage

* `make sync_data_up` will use `aws s3 sync` to recursively sync files in `data/` up to `s3://bucket_name/data/`.
* `make sync_data_down` will use `aws s3 sync` to recursively sync files from `s3://bucket_name/data/` to `data/`.


