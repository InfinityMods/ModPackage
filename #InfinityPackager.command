#!/bin/sh
command_path=$(cd "$(dirname "$0")"; pwd)
cd "$command_path"
pwsh -NoLogo -NoProfile -ExecutionPolicy Bypass -File "./#InfinityPackager.ps1" "$command_path"
exit 0
