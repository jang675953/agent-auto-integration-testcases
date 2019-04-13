#!/bin/bash
#
#ARG_POSITIONAL_SINGLE([agent_repo], [The agent repository URL to be run])
#ARG_POSITIONAL_SINGLE([agent_repo_branch], [The branch name of agent repository to be run])
#ARG_POSITIONAL_SINGLE([testcase_repo], [The testcase repository URL to be run])
#ARG_POSITIONAL_SINGLE([testcase_repo_branch], [The branch name of testcase repository to be run])
#ARG_OPTIONAL_REPEATED([scenario], [], [The scenarios to be run])
#ARG_OPTIONAL_SINGLE([issue_no], [], [The relate issue no], [UNKNOWN])
#ARG_OPTIONAL_BOOLEAN([build], [], [Skip build projects.])
#ARG_OPTIONAL_BOOLEAN([report], [], [Skip report the testcase to GitHub]. [off])
#ARG_OPTIONAL_BOOLEAN([clone_code], [], [Skip clone the code], [off])
#ARG_OPTIONAL_BOOLEAN([skip_single_mode_scenario], [], [Skip build the scenario with single mode], [on])
#ARG_OPTIONAL_SINGLE([collector_image_version],[], [The docker image version of mock collector], "6.0.0-2018")
#ARG_OPTIONAL_SINGLE([parallel_run_size], [], [The size of running testcase at the same time], 1)
#ARG_OPTIONAL_SINGLE([validate_log_url_prefix], [], [The url prefix of validate log url], [http://host:port/jenkins])
#DEFINE_SCRIPT_DIR([AGENT_TEST_HOME])
#ARG_HELP()
#ARGBASH_GO
# [

# declare variables
WORKSPACE=${AGENT_TEST_HOME}/workspace
SOURCE_CODE_DIR=${WORKSPACE}/source
AGENT_SOURCE_CODE=${SOURCE_CODE_DIR}/skywalking
VALIDATE_TOOL_SOURCE_CODE=${SOURCE_CODE_DIR}/validate-tool
AGENT_WITH_OPTIONAL_PLUGIN_DIR=${SOURCE_CODE_DIR}/agent-with-optional-plugins
REPORT_HOME=${WORKSPACE}/report
AGENT_DIR=${SOURCE_CODE_DIR}/agent
TESTCASES_HOME=${AGENT_TEST_HOME}/testcases
VALIDATE_TOOL_REPO=https://github.com/SkywalkingTest/agent-integration-testtool.git
VALIDATE_TOOL_REPO_BRANCH=master
OVERWRITE_README="on"
LOGS_DIR=${WORKSPACE}/logs

declare -a SCENARIOS
if [ ${#_arg_scenario[@]} -eq 0 ]; then
    for SCENARIO in `ls $AGENT_TEST_HOME`
    do
        if [ -f "${SCENARIO}/testcase.yml" ]; then
            SCENARIOS+=("${SCENARIO}")
        fi
    done
else
    SCENARIOS=("${_arg_scenario[@]}")
    OVERWRITE_README="off"
fi

echo "[INFO] Running parameteres:"
echo -e "  - Agent repository:\t\t${_arg_agent_repo}"
echo -e "  - Agent repository branch:\t${_arg_agent_repo_branch}"
echo -e "  - Testcase repository:\t${_arg_testcase_repo}"
echo -e "  - Testcase repository branch:\t${_arg_testcase_repo_branch}"
echo -e "  - Issue No:\t\t\t${_arg_issue_no}"
echo -e "  - Build:\t\t\t${_arg_build}"
echo -e "  - Report:\t\t\t${_arg_report}"
echo -e "  - Image version of collector:\t${_arg_collector_image_version}"
echo -e "  - parallel running number:\t${_arg_parallel_run_size}"
echo -e "  - Scenarios:\t\t\t${SCENARIOS[@]}"

# build workspace
if [ "${_arg_clone_code}" = "on" ]; then
    rm - rf ${WORKSPACE} && mkdir -p ${WORKSPACE} 
fi

rm -rf ${LOGS_DIR} && mkdir -p ${LOGS_DIR}

echo "[INFO] build workspace"
${AGENT_TEST_HOME}/.autotest/build_agent.sh --build ${_arg_build} ${_arg_agent_repo} ${_arg_agent_repo_branch} ${AGENT_SOURCE_CODE} >${LOGS_DIR}/agent-build.log && ${AGENT_TEST_HOME}/.autotest/build_validate_tool.sh --build ${_arg_build} ${VALIDATE_TOOL_REPO} ${VALIDATE_TOOL_REPO_BRANCH} ${VALIDATE_TOOL_SOURCE_CODE} && ${AGENT_TEST_HOME}/.autotest/build_report.sh ${REPORT_HOME}

AGENT_COMMIT_ID=$(cd $AGENT_SOURCE_CODE && git rev-parse HEAD)
TESTCASE_COMMIT_ID=$(cd $AGENT_TEST_HOME && git rev-parse HEAD)

# build testcase
echo "[INFO] build test case projects"
${AGENT_TEST_HOME}/build_testcases.sh --collector_image_version ${_arg_collector_image_version} --skip_single_mode ${_arg_skip_single_mode_scenario} . ${SCENARIOS} > ${LOGS_DIR}/testcase-build.log

# run test_case
${AGENT_TEST_HOME}/run.sh ${TESTCASES_HOME} >/dev/null

# generate report
${AGENT_TEST_HOME}/.autotest/generate-report.sh --agent_repo ${_arg_agent_repo} --agent_branch ${_arg_agent_repo_branch} --testcase_repo ${_arg_testcase_repo} --testcase_branch ${_arg_testcase_repo_branch} --agent_commitid ${AGENT_COMMIT_ID} --testcase_commitid ${TESTCASE_COMMIT_ID} --overwrite_readme ${OVERWRITE_README} --upload_report ${_arg_report} --issue_no ${_arg_issue_no} --validate_log_url_prefix ${_arg_validate_log_url_prefix} ${TESTCASES_HOME} ${REPORT_HOME} > ${LOGS_DIR}/validate.log

# ]