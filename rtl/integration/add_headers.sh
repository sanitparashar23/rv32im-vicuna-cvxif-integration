#!/bin/bash

JEFFREY_HEADER='// Original Author: Jeffrey Claudio
// Source: https://github.com/jeffreyc-dev/rv32im-5stage-cpu
// License: MIT License (see THIRD_PARTY_LICENSES.md)
'

VICUNA_HEADER='// Copyright TU Wien
// Licensed under the Solderpad Hardware License v2.1, see LICENSE.txt for details
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
// Source: https://github.com/vproc/vicuna
'

MODIFIED_NOTE='// Modified by Sanit Parashar for RV32IM-Vicuna CV-X-IF integration (2026)
// See THIRD_PARTY_LICENSES.md for details on scope of changes
'

ORIGINAL_MIT='// Author: Sanit Parashar
// Original work -- no upstream equivalent
// License: MIT License (see LICENSE)
'

RECONSTRUCTED_NOTE='// Reconstructed by Sanit Parashar from Vicunas config.mk generation logic (vproc/vicuna)
// Vicuna does not ship this file statically -- it is normally auto-generated at build time
// License: Solderpad Hardware License v2.1 / Apache License 2.0 (same terms as Vicuna)
'

prepend() {
  local file="$1"
  local header="$2"
  if [ -f "$file" ]; then
    { printf "%s\n" "$header"; cat "$file"; } > "$file.tmp" && mv "$file.tmp" "$file"
    echo "Updated: $file"
  else
    echo "Skipped (not found): $file"
  fi
}

# Jeffrey Core, modified
for f in rv32im.sv i_mem.sv control_unit.sv d_mem.sv hazard_unit.sv rv32im_top.sv; do
  prepend "$f" "$JEFFREY_HEADER$MODIFIED_NOTE"
done

# Vicuna, modified
prepend "vproc_core.sv" "$VICUNA_HEADER$MODIFIED_NOTE"

# Fully original
prepend "vicuna_wrapper.sv" "$ORIGINAL_MIT"

# Reconstructed
prepend "vproc_config.sv" "$RECONSTRUCTED_NOTE"

echo "Done."
