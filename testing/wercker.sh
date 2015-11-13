#!/bin/bash

set -e

export PREDICTED_CHECKSUM="0ab71a1c8fef24ade8d650e2cc248aac1e499a45a0e9456ba0b47901f99176d8"
export KVEXPRESS_DEBUG=1

echo "Launching Consul."
consul agent -data-dir `mktemp -d` -bootstrap -server -bind=127.0.0.1 1>/dev/null &
sleep 3
make sorting
echo "Putting 'sorting' into 'testing' key."
bin/kvexpress in -k testing -f sorting --sorted true
echo "Pulling 'testing' key out and saving it to 'output'."
bin/kvexpress out -k testing -f output

export CHECKSUM=$(shasum -a 256 output | cut -d ' ' -f 1)

echo "Set stop key"
bin/kvexpress stop -k testing -r "Setting a stop key."

echo "Try to pull it out - should not succeed."
bin/kvexpress out -k testing -f stopped

if [ -e "stopped" ]; then
  echo "Oops - something went wrong."
  exit 1
else
  echo "Perfect."
fi

echo "Ignore stop key - should succeed."
bin/kvexpress out -k testing -f ignored --ignore_stop

if [ -e "ignored" ]; then
  echo "Perfect."
else
  echo "Oops - something went wrong."
  exit 1
fi

echo "Testing clean command."
bin/kvexpress clean -f sorting
bin/kvexpress clean -f output
bin/kvexpress clean -f ignored

echo "Checksum : $CHECKSUM"
echo "Predicted: $PREDICTED_CHECKSUM"

echo "Let's try a URL based test."
bin/kvexpress in -k url -u https://gist.githubusercontent.com/darron/9753b203b32667484105/raw/e66ea4c28c59e54aa8234d742368ccf93527dce5/gistfile1.txt
bin/kvexpress out -k url -f url

export URL_CHECKSUM=$(shasum -a 256 url | cut -d ' ' -f 1)

echo "Predicted URL Checksum: '307b198c768b7a174b11e00c70bb1bd7b32597a86790279f763c4544dc12d1ff'"
echo "   Actual URL Checksum: '$URL_CHECKSUM'"

if [[ "$CHECKSUM" == "$PREDICTED_CHECKSUM" ]]; then
  echo "Looks good."
  exit 0
else
  echo "Looks bad - checksums don't match."
  exit 1
fi
