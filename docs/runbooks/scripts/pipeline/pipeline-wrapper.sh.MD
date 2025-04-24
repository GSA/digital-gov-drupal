### Runbook for `pipeline_wrapper.sh`

#### Introduction
The `pipeline_wrapper.sh` script is part of a deployment automation infrastructure, specifically designed to run a specified script within a Cloud Foundry (CF) environment. The script requires certain environment variables to be set and checks for their presence before proceeding with task execution. This script aims to run a task in a specified CF application space and monitor the task logs before cleaning up.

#### Technical Breakdown

##### Overview of Script Functionality

The `pipeline_wrapper.sh` script follows a workflow where:

1. The first argument is expected to be the name of the script to execute, otherwise, it exits with an error.
2. Checks for the environment variables `CF_SPACE` and `PROJECT`. If either is missing, the script outputs an error message and exits.
3. Runs a CF task in the specified environment, waits for its completion, and monitors relevant logs.
4. Cleans up after task completion.

##### Detailed Analysis

1. **Argument Validation**
   - The script first checks if an argument (the name of the script to run) is provided. If not, it outputs an error message and exits:
     ```bash
     if [ -z "${1}" ]; then
       echo "The name of the script to run must be the first argument"
       exit 1
     fi
     ```

2. **Environment Variable Checks**
   - It verifies the presence of two required environment variables: `CF_SPACE` and `PROJECT`. It checks each separately and outputs an error message if any are unset:
     ```bash
     if [ -z "${CF_SPACE}" ] || [ -z "${PROJECT}" ]; then
       if [ -z "${CF_SPACE}" ]; then
         echo "CF_SPACE must be set for " $(basename "$0")
       fi
       if [ -z "${PROJECT}" ]; then
         echo "PROJECT must be set for " $(basename "$0")
       fi
       exit 1
     fi
     ```

3. **Task Execution and Monitoring**
   - The script then constructs the `APP` and `TASK_NAME` variables based on the provided `PROJECT` and `CF_SPACE` environment variables.
     ```bash
     APP="${PROJECT}-drupal-${CF_SPACE}"
     TASK_NAME="${APP}-${1}"
     ```
   - It runs the task using `cf run-task` with the specified `APP` and a command to execute the script from `/home/vcap/app/scripts/`:
     ```bash
     cf run-task "${APP}" --command "/home/vcap/app/scripts/${1}" --wait -m 1G -k 4G --name "${TASK_NAME}" &
     ```
   - The script uses the PID of the background task to track its completion:
     ```bash
     RUN_TASK_PID=$!
     ```

4. **Monitoring Logs**
   - The script also sets up a separate process to tail the relevant logs for the application:
     ```bash
     cf logs "${APP}" | grep "${TASK_NAME}" &
     sleep 1
     CF_LOGS_PID=$(pgrep -f "cf logs")
     ```

5. **Cleanup**
   - After task completion, the script waits for the task pid (`RUN_TASK_PID`) to be done. Then, it kills the log tailing process to prevent it from running indefinitely:
     ```bash
     wait "${RUN_TASK_PID}"
     kill "${CF_LOGS_PID}"
     ```

#### Troubleshooting

- **Argument Validation Failure**:
  - If the first argument (script name) is missing, the script fails with the exit message "The name of the script to run must be the first argument".
  
- **Environment Variable Absence**:
  - If either `CF_SPACE` or `PROJECT` is not set, the script will output which variable is missing and exit with an informative error message.
  
- **Task Execution Errors**:
  - Ensure that the specified script at `/home/vcap/app/scripts/${1}` exists and is executable within the specified application context.
  
- **Monitoring Logs**:
  - If logs are not found or `cf logs` command fails, ensure that the `cf-cli` is correctly configured and the application has the necessary access to CF services.

- **Task PID Handling**:
  - If the task fails to launch, `RUN_TASK_PID` may not be set, leading to undefined behavior. Always check the PID output and ensure successful task launching before proceeding.
