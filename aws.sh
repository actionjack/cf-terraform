#!/bin/sh

DEPLOY_ENV=${DEPLOY_ENV:-smashmouth}
TARGET=${TARGET:-aws}

echo make ${TARGET} DEPLOY_ENV=${DEPLOY_ENV}
