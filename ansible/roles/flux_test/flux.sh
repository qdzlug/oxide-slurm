#!/bin/bash
export SPACK_ROOT=/opt/spack
. $SPACK_ROOT/share/spack/setup-env.sh
spack load gcc@13
spack load flux-core
spack load openmpi
export FLUX_CONF_DIR=/etc/flux
export FLUX_LOG_LEVEL=info
