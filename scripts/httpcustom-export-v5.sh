#!/bin/bash
# Wrapper: httpc-export-v5 <profile_id> <ssh_user> [ssh_pass] [output.json]
exec /usr/local/sbin/httpcustom-export "$@"
