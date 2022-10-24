#!/bin/bash

echo Patching node_modules/react-scripts/config/webpack.config.js for ip-address package

# exclude: /@babel(?:\/|\\{1,2})runtime/,
# exclude: /@babel(?:\/|\\{1,2})runtime|ip-address/
COUNT=$(grep 'exclude: /@babel(?:\\/|\\\\{1,2})runtime/,' node_modules/react-scripts/config/webpack.config.js | wc -l)

set -x

if [ x${COUNT} = x2 ] ; then
  sed  -i "s|)runtime/,$|)runtime\|ip-address/,|g" node_modules/react-scripts/config/webpack.config.js
else
  echo '== Unable to patch webpack.config.js'
fi

