#!/bin/bash
# Copyright (C) 2022 Pablo Iranzo Gómez <Pablo.Iranzo@gmail.com>
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.

# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.

# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.

# long_name: Checks if there are pending CSRs
# description: Checks pending CSRs
# priority: 900
# bugzilla:

# Load common functions
[[ -f "${RISU_BASE}/common-functions.sh" ]] && . "${RISU_BASE}/common-functions.sh"

FILE="${KUBECONFIG}"
is_mandatory_file ${FILE}

is_required_command oc

COUNT=$(oc get csr -A --no-headers | grep -v Approved | wc -l)
DETAIL=$(oc get csr -A --no-headers | grep -v Approved)
WHAT="Pending CSR"

if [ "${COUNT}" == 0 ]; then
    #   Nothing found
    exit ${RC_OKAY}
else
    echo -e "${WHAT} found:\n ${DETAIL}" >&2
    exit ${RC_FAILED}
fi
