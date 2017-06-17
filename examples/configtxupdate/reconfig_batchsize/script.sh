#!/bin/bash

CDIR=$(dirname $(basename "$0"))

# Defaults
: ${CHANNEL:="testchainid"}
: ${OUTDIR:="example_output"}
mkdir -p ${OUTDIR} || die "could not create output dir ${OUTDIR}"

CONFIG_BLOCK_PB="${OUTDIR}/config_block.pb"
CONFIG_BLOCK_JSON="${OUTDIR}/config_block.json"
CONFIG_JSON="${OUTDIR}/config.json"
CONFIG_PB="${OUTDIR}/config.pb"
UPDATED_CONFIG_JSON="${OUTDIR}/updated_config.json"
UPDATED_CONFIG_PB="${OUTDIR}/updated_config.pb"
CONFIG_UPDATE_PB="${OUTDIR}/config_update.pb"
CONFIG_UPDATE_JSON="${OUTDIR}/config_update.json"
CONFIG_UPDATE_IN_ENVELOPE_PB="${OUTDIR}/config_update_in_envelope.pb"
CONFIG_UPDATE_IN_ENVELOPE_JSON="${OUTDIR}/config_update_in_envelope.json"

. ${CDIR}/../common_scripts/common.sh

bigMsg "Beginning config update batchsize example"

findPeer || die "could not find peer binary"

bigMsg "Fetching current config block"

fetchConfigBlock "${CHANNEL}" "${CONFIG_BLOCK_PB}"

bigMsg "Decoding current config block"

decode common.Block "${CONFIG_BLOCK_PB}" "${CONFIG_BLOCK_JSON}"

bigMsg "Isolating current config"

echo -e "Executing:\tjq .data.data[0].payload.data.config '${CONFIG_BLOCK_JSON}' > '${CONFIG_JSON}'"
jq .data.data[0].payload.data.config "${CONFIG_BLOCK_JSON}" > "${CONFIG_JSON}" || die "Unable to extract config from config block"

pauseIfInteractive

bigMsg "Generating new config"

OLD_BATCH_SIZE=$(jq ".channel_group.groups.Orderer.values.BatchSize.value.max_message_count" "${CONFIG_JSON}")
NEW_BATCH_SIZE=$(($OLD_BATCH_SIZE+1))

echo -e "Executing:\tjq '.channel_group.groups.Orderer.values.BatchSize.value.max_message_count = $NEW_BATCH_SIZE' '${CONFIG_JSON}'  > '${UPDATED_CONFIG_JSON}'"
jq ".channel_group.groups.Orderer.values.BatchSize.value.max_message_count = $NEW_BATCH_SIZE" "${CONFIG_JSON}"  > "${UPDATED_CONFIG_JSON}" || die "Error updating batch size"

pauseIfInteractive

bigMsg "Translating original config to proto"

encode common.Config "${CONFIG_JSON}" "${CONFIG_PB}"

bigMsg "Translating updated config to proto"

encode common.Config "${UPDATED_CONFIG_JSON}" "${UPDATED_CONFIG_PB}"

bigMsg "Computing config update"

computeUpdate "${CHANNEL}" "${CONFIG_PB}" "${UPDATED_CONFIG_PB}" "${CONFIG_UPDATE_PB}"

bigMsg "Decoding config update"

decode common.ConfigUpdate "${CONFIG_UPDATE_PB}" "${CONFIG_UPDATE_JSON}"

bigMsg "Generating config update envelope"

wrapConfigEnvelope "${CONFIG_UPDATE_JSON}" "${CONFIG_UPDATE_IN_ENVELOPE_JSON}"

bigMsg "Encoding config update envelope"

encode common.Envelope "${CONFIG_UPDATE_IN_ENVELOPE_JSON}" "${CONFIG_UPDATE_IN_ENVELOPE_PB}"

bigMsg "Sending config update to channel"

updateConfig ${CHANNEL} "${CONFIG_UPDATE_IN_ENVELOPE_PB}"

bigMsg "Config Update Successful!"
