#!/bin/bash

#
#	test_mixed_tp of perf_probe test
#	Author: Michael Petlan <mpetlan@redhat.com>
#
#	Description:
#
#		This test tests bug addressed by the following kernel patch:
#
#			commit 96167167b6e17b25c0e05ecc31119b73baeab094
#			Author: Andi Kleen <ak@linux.intel.com>
#			Date:   Thu Jan 17 11:48:34 2019 -0800
#			perf script: Fix crash with printing mixed trace point and other events
#

# include working environment
. ../common/init.sh
. ./settings.sh

THIS_TEST_NAME=`basename $0 .sh`
TEST_RESULT=0

check_uprobes_available
if [ $? -ne 0 ]; then
	print_overall_skipped
	exit 0
fi

clear_all_probes


### add uprobe

# we need a uprobe
$CMD_PERF probe -x $CURRENT_TEST_DIR/examples/advanced 'main' > $LOGS_DIR/mixed_tp_add.log 2> $LOGS_DIR/mixed_tp_add.err
PERF_EXIT_CODE=$?

../common/check_all_patterns_found.pl "probe_advanced:main" "examples/advanced" < $LOGS_DIR/mixed_tp_add.err
CHECK_EXIT_CODE=$?

print_results $PERF_EXIT_CODE $CHECK_EXIT_CODE "add uprobe"
(( TEST_RESULT += $? ))


### record uprobe

# record the uprobe
PROBE_PREFIX=`head -n 2 $LOGS_DIR/mixed_tp_add.err | perl -ne 'print "$1" if /\s+(\w+):\w/'`
$CMD_PERF record -e "$PROBE_PREFIX:"'*' $CURRENT_TEST_DIR/examples/advanced > /dev/null 2> $LOGS_DIR/mixed_tp_record_uprobe.err
PERF_EXIT_CODE=$?

../common/check_all_patterns_found.pl "$RE_LINE_RECORD1" "$RE_LINE_RECORD2" < $LOGS_DIR/mixed_tp_record_uprobe.err
CHECK_EXIT_CODE=$?

print_results $PERF_EXIT_CODE $CHECK_EXIT_CODE "record uprobe"
(( TEST_RESULT += $? ))


### script with uprobe

# here might be the problem (non matching sample_id_all)
$CMD_PERF script -i $CURRENT_TEST_DIR/perf.data > $LOGS_DIR/mixed_tp_script_uprobe.log 2> $LOGS_DIR/mixed_tp_script_uprobe.err
PERF_EXIT_CODE=$?

../common/check_no_patterns_found.pl "non matching" "sample_id_all" < $LOGS_DIR/mixed_tp_script_uprobe.err
CHECK_EXIT_CODE=$?
REGEX_SCRIPT_LINE="\s*advanced\s+$RE_NUMBER\s+\[$RE_NUMBER\]\s+$RE_NUMBER:\s+$PROBE_PREFIX"
../common/check_all_lines_matched.pl "$REGEX_SCRIPT_LINE" < $LOGS_DIR/mixed_tp_script_uprobe.log 
(( CHECK_EXIT_CODE += $? ))

print_results $PERF_EXIT_CODE $CHECK_EXIT_CODE "script uprobe"
(( TEST_RESULT += $? ))


### record mixed events

# record mixed uprobes
$CMD_PERF record -e '{cpu-clock'",$PROBE_PREFIX:"'*}:S' $CURRENT_TEST_DIR/examples/advanced > /dev/null 2> $LOGS_DIR/mixed_tp_record_mixed.err
PERF_EXIT_CODE=$?

../common/check_all_patterns_found.pl "$RE_LINE_RECORD1" "$RE_LINE_RECORD2" < $LOGS_DIR/mixed_tp_record_mixed.err
CHECK_EXIT_CODE=$?

print_results $PERF_EXIT_CODE $CHECK_EXIT_CODE "record mixed events"
(( TEST_RESULT += $? ))


### script with mixed events

# here might be the problem (non matching sample_id_all)
$CMD_PERF script -i $CURRENT_TEST_DIR/perf.data > $LOGS_DIR/mixed_tp_script_mixed.log 2> $LOGS_DIR/mixed_tp_script_mixed.err
PERF_EXIT_CODE=$?

../common/check_no_patterns_found.pl "non matching" "sample_id_all" < $LOGS_DIR/mixed_tp_script_mixed.err
CHECK_EXIT_CODE=$?
REGEX_SCRIPT_LINE_PROBE="\s*advanced\s+$RE_NUMBER\s+\[[\d\-]+\]\s+$RE_NUMBER:\s+$PROBE_PREFIX:"
REGEX_SCRIPT_LINE_SOFTWARE="\s*advanced\s+$RE_NUMBER\s+$RE_NUMBER:\s+$RE_NUMBER\s+cpu-clock:?\s+$RE_NUMBER_HEX"
../common/check_all_lines_matched.pl "$REGEX_SCRIPT_LINE_PROBE" "$REGEX_SCRIPT_LINE_SOFTWARE" < $LOGS_DIR/mixed_tp_script_mixed.log 
(( CHECK_EXIT_CODE += $? ))
../common/check_all_patterns_found.pl "$REGEX_SCRIPT_LINE_PROBE" "$REGEX_SCRIPT_LINE_SOFTWARE" < $LOGS_DIR/mixed_tp_script_mixed.log 
(( CHECK_EXIT_CODE += $? ))

print_results $PERF_EXIT_CODE $CHECK_EXIT_CODE "script mixed events"
(( TEST_RESULT += $? ))

# print overall results
print_overall_results "$TEST_RESULT"
exit $?
