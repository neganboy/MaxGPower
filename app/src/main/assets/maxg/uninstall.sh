#!/system/bin/sh
MODDIR=${0%/*}
. "$MODDIR/lib.sh"
heatd_stop
autod_stop
tune_revert_all
btg_revert
padd_stop
claim_release_all
gpud_stop
bt_fast_restore
reset_all
