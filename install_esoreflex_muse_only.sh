#!/bin/sh

trap InstallationInterrupted 2


#This function checks which pipelines have an available Reflex workflow
#and stores in file "${download_dir}"/available_pipelines the following info:
#Pipeline  Version Data Pipeline-kit Demodataset
GetAvailablePipelines()
{
  cd "${tempdir}"
  if [ $offline -eq 0 ] ; then
    $httpcommand https://ftp.eso.org/pub/dfs/pipelines/repositories/${release_channel}/kit/reflex_cfg/reflex_${release_channel}.txt > /dev/null 2>&1
    if [ $? -ne 0 ]; then
      echo ERROR: Could not retrieve available pipelines.
      echo ERROR: Please make sure you have access to ESO webpages
      echo ERROR: Also, try with the latest version of install_esoreflex
      echo ERROR:       from https://www.eso.org/sci/software/pipelines/install_esoreflex
      echo ERROR: If problem persists, contact usd-help@eso.org
      Cleanup
      exit 1
    fi
    sort -k 1 reflex_${release_channel}.txt | uniq > available_pipelines_sorted
    \mv -f available_pipelines_sorted available_pipelines
    if [ ! -s available_pipelines ]
    then
      echo
      echo ERROR: No pipelines are available in this release channel
      Cleanup
      exit 1
    fi
    \rm -f "${tempdir}/index.html"
    \cp available_pipelines "${download_dir}"
  else
    if [ ! -f "${download_dir}"/available_pipelines ] ; then
      echo ERROR: The following file needed in offline mode is missing:
      echo ERROR: ${download_dir}/available_pipelines
      Cleanup
      exit 1
    fi
  fi
}

GetInstalledPipelines()
{
  if [ -f "${installation_dir}/etc/vltpipe_reflex_install/installed_pipelines" ]
  then
    echo ==================================================================
    echo The following pipelines and associated demo dataset
    echo are already installed in your system:
    echo 'Instrument       Version'
    awk '{printf("%-16s %-22s\n",$1,$2)}' "${installation_dir}/etc/vltpipe_reflex_install/installed_pipelines"
    echo
    echo The current procedure will first delete all the installed pipelines
    echo \(but not the datasets\) and then install the requested ones
    echo \(unless all currently installed pipelines are exactly
    echo the same as the all requested pipelines\)
    printf "Do you want to continue [Y/n]? "
    read -r proceed
    proceed=`echo $proceed | tr '[:upper:]' '[:lower:]'`
    if [ "x$proceed" = "xn" ] ; then
      echo Aborting
      Cleanup
      exit 1
    fi
  fi
}

GetInstalledReflex()
{
  if [ -f "${installation_dir}/etc/vltpipe_reflex_install/installed_reflex" ]
  then
    echo ==================================================================
    echo The following Reflex version is already installed in you system:
    cat "${installation_dir}/etc/vltpipe_reflex_install/installed_reflex" | sed 's%.*://ftp.eso.org/pub/dfs/reflex/%%g' | sed 's%.tar.gz%%g'
  fi
}

#This function will show the available pipelines and their versions and
#will prompt for the desired pipelines to be installed
GetPipelinesToInstall()
{
  cd "${tempdir}"
  echo ==================================================================
  echo "File edited by tans! Automatically selected MUSE pipeline for install"
  echo ==================================================================

  # Clear existing pipelines_to_install file
  \rm -f pipelines_to_install

  # Add MUSE pipeline (assuming PipeID 15 corresponds to MUSE)
  awk '{if (NR == 16) printf("%s   %s\n", $1, $2)}' "${download_dir}/available_pipelines" > pipelines_to_install

  if [ -s pipelines_to_install ]; then
    echo "The following pipeline has been selected for installation:"
    cat pipelines_to_install
  else
    echo "ERROR: Unable to select the MUSE pipeline. Please check the available_pipelines file."
    Cleanup
    exit 1
  fi

  echo
}

#This function will select the desired demo data to be installed
GetPipelineDemoDataToInstall()
{
  cd "${tempdir}"
  if [ ! -f pipelines_to_install ] ; then
    return
  fi
  echo ==================================================================
  echo Pipeline workflows are distributed with demo data that allows
  echo to run the workflow right away.
  echo Please specify \'A\' to install all available demo data \(recommended\),
  echo \'None\' to not install any demo data, or a
  echo selection of demo data by writing a space-separated list of the PipeIDs.
  echo 'PipeID    Instrument       Version'
  awk '{printf("%-9d %-16s %-22s\n",NR,$1,$2)}' pipelines_to_install
  echo
  while :
  do
    printf  "Input PipeIDs for demo data to install [A]: "
    read -r pipedata_numbers_to_install
    if [ -z "$pipedata_numbers_to_install" ] ; then
      pipedata_numbers_to_install="A"
    fi

    \rm -f pipedata_to_install
    number_pipe_data=`wc -l < pipelines_to_install`
    cat -n pipelines_to_install | while read pipeid pipename pipever somethings
    do
      echo ${pipeid} ${pipename} ${pipever} ${pipedata_numbers_to_install} | awk -v number_pipe_data="$number_pipe_data" '{for(i=4; i<=NF; i++){if( $i != "None" && $i != "A" && ( ( $i != $i + 0 ) ||  ( ( $i == $i + 0 ) && ( ( $i < 1 ) || ( $i > number_pipe_data ) ) ) ) ) {print "WARNING: Invalid input. Enter numbers in the valid range, None or A."};  if( $i == $1 || $i == "A" ){printf("%s   %s\n", $2, $3)}}}' >> pipedata_to_install
    done

    grep WARNING pipedata_to_install | head -1
    if grep WARNING pipedata_to_install > /dev/null
    then
      echo
    else
      break
    fi
  done

  echo
}

GetReflexToInstall()
{
  cd "$tempdir"
  echo ==================================================================
  echo The following Reflex version is the latest one available:
  cat "${download_dir}"/reflex_version
  cp "${download_dir}"/reflex_version reflex_to_install

  if [ -f "${installation_dir}/etc/vltpipe_reflex_install/installed_reflex" ]
  then
    diff "${tempdir}/reflex_to_install" "${installation_dir}/etc/vltpipe_reflex_install/installed_reflex" > difference_installed_reflex
    local lines_diff_inst=`wc -l < difference_installed_reflex`
    if [ $lines_diff_inst -eq 0 ]
    then
      \rm -f "${tempdir}/reflex_to_install"
    else
      \cp "${installation_dir}/etc/vltpipe_reflex_install/installed_reflex" "${tempdir}/reflex_to_remove"
      \cp "${installation_dir}/etc/vltpipe_reflex_install/installed_reflex_path" "${tempdir}/reflex_path_to_remove"
    fi
  fi
}

GetAvailableReflexVersion()
{
  cd "${tempdir}"

  if [ $offline -eq 0 ] ; then
    ${httpcommand}  http://www.eso.org/sci/software/esoreflex/releases/${release_channel}/index.html > /dev/null 2>&1
    if [ $? -ne 0 ]; then
      echo ERROR: Could not retrieve available Reflex versions.
      echo ERROR: Please make sure you have access to ESO webpages
      echo ERROR: If problem persists, contact usd-help@eso.org
      Cleanup
      exit 1
    fi

    awk '/tar.gz/' index.html | awk -F "<|>" '{gsub(/a href=/,"",$2); gsub(/"/,"",$2); print $2}' > reflex_package
    cat reflex_package | sed 's%https://ftp.eso.org/pub/dfs/reflex/%%g' | sed 's%.tar.gz%%g' > reflex_version
#    echo The available version of Reflex is:
#    cat reflex_version
    echo
    \rm -f "${tempdir}/index.html"
    \cp reflex_version "${download_dir}"
  else
    if [ ! -f "${download_dir}"/reflex_version ] ; then
      echo ERROR: The following file needed in offline mode is missing:
      echo ERROR: ${download_dir}/reflex_version
      Cleanup
      exit 1
    fi
  fi
}

WriteInstalledPackagesConfiguration()
{
  CreateDirectory "${installation_dir}/etc/vltpipe_reflex_install"
  if [ -f "${tempdir}/pipelines_to_install" ] ; then
    \cp "${tempdir}/pipelines_to_install" "${installation_dir}/etc/vltpipe_reflex_install/installed_pipelines"
  fi
  if [ -f "${tempdir}/reflex_to_install" ] ; then
    \cp "${download_dir}/reflex_version" "${installation_dir}/etc/vltpipe_reflex_install/installed_reflex"
    \cp "${tempdir}/reflex_base_path" "${installation_dir}/etc/vltpipe_reflex_install/installed_reflex_path"
  fi
}

AskOffline()
{

  echo ==================================================================
  echo This install script requires an internet connection to check for
  echo the latest versions of the software and download them if necessary.
  echo It can work without an internet connection if the download directory
  echo  \($download_dir\) contains already the needed files,
  echo either from a previous run of the script or copied from some media.
  printf "Do you want to use your internet connection [Y/n]? "
  read -r offline
  offline=`echo $offline | tr '[:upper:]' '[:lower:]'`
  if [ "x$offline" = "xn" ] ; then
    offline=1
  else
    offline=0
  fi
}

#Present a summary of the steps to be done and will exit if not confirmed
ConfirmInstallation()
{
  cd "${tempdir}"
  echo ==================================================================
  if [ -f pipelines_to_install ] ; then
    echo The following pipelines will be installed/reinstalled:
    cat pipelines_to_install
    echo
    echo The following demo data sets will be installed:
    cat pipedata_to_install
  else
    echo No pipelines or associated demo dataset will be installed.
    echo Current installed pipelines and associated demo dataset are kept.
  fi
  echo

  if [ -f reflex_to_install ] ; then
    echo The following Reflex version will be installed:
    cat reflex_to_install
  else
    echo The current Reflex version will be kept.
  fi
  echo
  echo ==================================================================

  if [ ! -f reflex_to_install ] && [ ! -f pipelines_to_install ] ; then
    echo Current Reflex and pipeline installations will be kept.
    echo There is nothing to be done. Exiting
    Cleanup
    exit 1
  fi

  echo "The following directories will be used:"
  echo "Directory for temporary downloaded files:   " $download_dir
  echo "Directory for installation of all software: " $installation_dir
  echo "Directory for demo datasets:                " $dataset_dir
  echo

  printf "Please confirm to proceed [Y/n]: "
  read -r proceed
  proceed=`echo $proceed | tr '[:upper:]' '[:lower:]'`
  if [ "x$proceed" = "xn" ] ; then
    echo Aborting
    Cleanup
    exit 1
  fi

  echo WARNING: Please, do not interrupt the installation from this point on
  echo WARNING: Otherwise you might get a broken installation
}

#Do the installation of the pipelines
InstallPipelines()
{
  if [ -f "${tempdir}/pipelines_to_install" ] ; then

    cd "${download_dir}"
    local all_pipeline_kits=
    local all_pipeline_data=
    while read pipename pipeversion
    do
      echo Downloading ${pipename} pipeline
      local pipekit=`grep "^${pipename} " "${download_dir}/available_pipelines" | awk '{print $3}' `
      local pipe_kit_name=`echo $pipekit  | awk -F'/' '{print $(NF)}'`
      if [ $offline -eq 0 ] ; then
        ${httpcommand} $pipekit > /dev/null 2>&1
        if [ $? -ne 0 ]; then
          echo ERROR: Could not retrieve pipeline kit. Check disk space or permissions
          echo ERROR: You might also want to delete old downloads from ${download_dir}
          Cleanup
          exit 1
        fi
        ${httpcommand} $pipekit.cksum > /dev/null 2>&1
      else
        if [ ! -f $pipe_kit_name ] ; then
          echo ERROR: The following file needed in offline mode is missing:
          echo ERROR: "${download_dir}"/$pipe_kit_name
          Cleanup
          exit 1
        fi
      fi
      all_pipeline_kits=`echo $all_pipeline_kits "${download_dir}/$pipe_kit_name"`
      cut -f 1,2 -d' ' $pipe_kit_name.cksum > "${tempdir}/$pipe_kit_name.cksum.orig"
      cat $pipe_kit_name | cksum > "${tempdir}/$pipe_kit_name.cksum.computed"
      diff "${tempdir}/$pipe_kit_name.cksum.computed" "${tempdir}/$pipe_kit_name.cksum.orig" > /dev/null
      if [ ! $? -eq 0 ]
        then
        echo ERROR: The pipeline kit contains errors in the checksum.
        echo Remove ${download_dir} and start over.
        Cleanup
        exit 1
      fi

    done < "${tempdir}/pipelines_to_install"

    echo Downloading pipeline installation script
    if [ $offline -eq 0 ] ; then
      \rm -f install_pipelinekit
      ${httpcommand} https://ftp.eso.org/pub/dfs/pipelines/repositories/${release_channel}/kit/reflex_cfg/install_pipelinekit_${release_channel} > /dev/null 2>&1
      mv install_pipelinekit_${release_channel} install_pipelinekit
      chmod u+x install_pipelinekit
    else
      if [ ! -f install_pipelinekit ] ; then
        echo ERROR: The following file needed in offline mode is missing:
        echo ERROR: "${download_dir}"/install_pipelinekit
        Cleanup
        exit 1
      fi
    fi

    echo
    echo Executing pipeline installation script starting at `date`.
    echo This might take a while, around 10 minutes per pipeline.
    echo Inspect the following file if you want to check progress:
    echo ${download_dir}/install.log
    echo
    ./install_pipelinekit -ignore_esorex_rc -ignore_gasgano "${installation_dir}" "${installation_dir}" $all_pipeline_kits > "${tempdir}/install_pipelinekit.log" 2>&1
    if [ $? -ne 0 ]; then
      if [ ! -f "${download_dir}/install.log" ] ; then
        # In case the command completely failed even to generate a log,
        # copy piped output to the log file.
        \cp "${tempdir}/install_pipelinekit.log" "${download_dir}/install.log"
      fi
      echo ERROR: Could not install pipelines.
      echo ERROR: Check "${download_dir}"/install.log to verify what went wrong
      echo ERROR: If error persists, send a report to usd-help@eso.org
      echo ERROR: including the following files:
      echo "${download_dir}/install.log"
      find "${download_dir}" -name config.log
      # Do not call Cleanup since it will remove the pipeline-kit-*.tmp directory.
      # Cleanup only the install_esoreflex_temp.* directory.
      RemoveTempDir
      exit 1
    fi
    echo Installation of pipelines successful.

    echo Installing pipeline demo data
    while read pipename pipeversion
    do
      if grep "^$pipename " "${tempdir}/pipedata_to_install" > /dev/null 2>&1 ; then
        echo Downloading ${pipename} data
        local pipedata=`grep "^${pipename} " "${download_dir}"/available_pipelines | awk '{print $4}' `
        local pipe_data_name=`echo $pipedata  | awk -F'/' '{print $(NF)}' `
        local pipe_name=`echo $pipe_data_name | awk -F'-' '{print $1}' `
        if [ $offline -eq 0 ] ; then
          ${httpcommand} $pipedata > /dev/null 2>&1
          if [ $? -ne 0 ]; then
            echo ERROR: Could not retrieve pipeline data $pipedata.
            echo ERROR: Check disk space or permissions
            Cleanup
            exit 1
          fi
        else
          if [ ! -f $pipe_data_name ] ; then
            echo ERROR: The following file needed in offline mode is missing:
            echo ERROR: "${download_dir}"/$pipe_data_name
            Cleanup
            exit 1
          fi
        fi
        echo Installing ${pipename} data
        file $pipe_data_name  > "${tempdir}/file_tmp" 2>&1
        grep gzip "${tempdir}/file_tmp" > /dev/null 2>&1
        if [ $? -eq 0 ]; then
          compress_opt=z
        fi
        grep bzip2 "${tempdir}/file_tmp" > /dev/null 2>&1
        if [ $? -eq 0 ]; then
          compress_opt=j
        fi
        # Both lower and upper case needs to be handled since the output string
        # is declared differently with the 'file' command on Mac OSX and Linux.
        grep xz "${tempdir}/file_tmp" > /dev/null 2>&1
        if [ $? -eq 0 ]; then
          compress_opt=J
        fi
        grep XZ "${tempdir}/file_tmp" > /dev/null 2>&1
        if [ $? -eq 0 ]; then
          compress_opt=J
        fi
        if [ ! -d "${dataset_dir}/reflex_input/${pipe_name}" ] ; then
          CreateDirectory "${dataset_dir}/reflex_input/${pipe_name}"
        fi
        tar -${compress_opt} -xf $pipe_data_name -C "${dataset_dir}/reflex_input/${pipe_name}" > /dev/null 2>&1
        if [ $? -ne 0 ]; then
          echo WARNING: Could not install pipeline data. Check disk space or permissions
          echo WARNING: Installation will continue without this data being installed
        fi
        \rm -rf "${tempdir}/file_tmp"

      fi
    done < "${tempdir}/pipelines_to_install"
    echo Installation of pipeline data succeed.
  fi
}

# Sets the version file if it is missing in the installed path.
#
PatchReflexVersionFile()
{
  local reflex_version=`cat "${download_dir}/reflex_version"`
  local reflex_base_path=`cat "${tempdir}/reflex_base_path"`
  if [ ! -f "${reflex_base_path}/esoreflex/version" -a -d "${reflex_base_path}/esoreflex" ] ; then
    if echo "${reflex_version}" | \grep '^reflex-' > /dev/null ; then
      # Update to new naming scheme with the 'eso' prefix.
      echo "eso${reflex_version}" > "${reflex_base_path}/esoreflex/version"
    else
      echo "${reflex_version}" > "${reflex_base_path}/esoreflex/version"
    fi
    if [ $? -ne 0 ]; then
      echo ERROR: Could not create the Reflex version file.
      Cleanup
      exit 1
    fi
  fi
}

# Download and copy the launch script if dealing with an older Reflex package.
# Also remove old launch scripts to prevent confusion or problems.
#
PatchLaunchScripts()
{
  local reflex_base_path=`cat "${tempdir}/reflex_base_path"`
  local reflex_sub_path="esoreflex"
  for script in esoreflex esoreflex_set_memory ; do
    if [ ! -f "${reflex_base_path}/${reflex_sub_path}/bin/${script}" ] ; then
      if [ ! -f "${download_dir}/${script}" ] ; then
        if [ $offline -eq 0 ] ; then
          cd "${download_dir}"
          ${httpcommand} "https://ftp.eso.org/pub/dfs/reflex/${script}" > /dev/null 2>&1
          if [ $? -ne 0 ]; then
            echo ERROR: Could not download the "${script}" script. Check disk space or permissions.
            echo ERROR: You might also want to delete old downloads from "${download_dir}"
            Cleanup
            exit 1
          fi
        else
          echo ERROR: The following file needed in offline mode is missing:
          echo ERROR: "$script"
          Cleanup
          exit 1
        fi
      fi
      \cp "${download_dir}/${script}" "${reflex_base_path}/${reflex_sub_path}/bin/${script}"
      if [ $? -ne 0 ]; then
        echo ERROR: Failed to copy the "${script}" script to the installation directory.
        Cleanup
        exit 1
      fi
    fi
  done
  # Remove old launch scripts so they cannot be picked up via the PATH variable.
  for script in "${reflex_base_path}/${reflex_sub_path}/bin/reflex" \
                "${reflex_base_path}/${reflex_sub_path}/bin/esoreflex.old" ; do
    if [ -f "${script}" ] ; then
      \rm -f "${script}"
    fi
  done
}

# This will move the Reflex folder to follow the naming scheme: esoreflex-*
# The installed folder is in addition identified by creation time in case there
# are multiple directories with the same name.
# Finally the new Reflex base path is written to ${tempdir}/reflex_base_path for
# later use.
#
UpdateReflexBasePath()
{
  local reflex_name=`cat "${tempdir}/reflex_to_install"`
  local untarred_reflex_dir=$(\ls -t "${installation_dir}" | \grep "${reflex_name}" | \head -n 1)
  if [ -z "${untarred_reflex_dir}" ] ; then
    echo ERROR: Could not find untarred Reflex package directory.
    Cleanup
    exit 1
  fi
  reflex_base_path="${installation_dir}/${untarred_reflex_dir}"
  echo "${reflex_base_path}" > "${tempdir}/reflex_base_path"
}

# Prints the full path to the ESO module subdirectory in the Reflex base path.
#
GetEsoSubDir()
{
  local reflex_base_path=""
  if [ -f "${tempdir}/reflex_base_path" ] ; then
    reflex_base_path=`cat "${tempdir}/reflex_base_path"`
  else
    reflex_base_path=`cat "${installation_dir}/etc/vltpipe_reflex_install/installed_reflex_path"`
  fi
  printf %s "${reflex_base_path}/esoreflex"
}

# Prints the full correct path to a script name in the Reflex bin directory,
# taking into account older Reflex package layouts.
#   $1 - The name of the script.
#
GetBinScriptPath()
{
  printf %s "`GetEsoSubDir`/bin/$1"
}

# Writes modifications to the esoreflex launch script to setup the various
# installation and workflow paths. Will also make sure the script is executable.
#
UpdateReflexCommand()
{
  local reflex_base_path=`cat "${tempdir}/reflex_base_path"`
  local script_path=`GetBinScriptPath esoreflex`
  \sed "s|^ESOREFLEX_BASE=.*$|ESOREFLEX_BASE=\"${reflex_base_path}\"|g" "${script_path}" | \
    \sed "s|^ESOREFLEX_WORKFLOW_PATH=.*$|ESOREFLEX_WORKFLOW_PATH=\"${installation_dir}/share/reflex/workflows\":~/KeplerData/workflows/MyWorkflows|g" | \
    \sed "s|^LOAD_ESOREX_CONFIG=.*$|LOAD_ESOREX_CONFIG=\"${installation_dir}/etc/esorex.rc\"|g" | \
    \sed "s|^LOAD_ESOREX_RECIPE_CONFIG=.*$|LOAD_ESOREX_RECIPE_CONFIG=\"${installation_dir}/etc/esoreflex_default_recipe_config.rc\"|g" | \
    \sed "s|^ESOREFLEX_SYSTEM_RC=.*$|ESOREFLEX_SYSTEM_RC=\"${installation_dir}/etc/esoreflex.rc\"|g" \
    > "${script_path}.tmp"
  if [ $? -ne 0 ]; then
    echo ERROR: Failed to update the esoreflex script.
    Cleanup
    exit 1
  fi
  \mv "${script_path}.tmp" "${script_path}"
  if [ $? -ne 0 ]; then
    echo ERROR: Failed to update the esoreflex script.
    Cleanup
    exit 1
  fi
  \chmod 755 "${script_path}"
  if [ $? -ne 0 ]; then
    echo ERROR: Failed to update file mode bits for the esoreflex script.
    Cleanup
    exit 1
  fi
}

# Writes modifications to the esoreflex_set_memory script to setup the base path
# where Reflex was installed. Will also make sure the script is executable.
#
UpdateSetMemoryCommand()
{
  local reflex_base_path=`cat "${tempdir}/reflex_base_path"`
  local script_path=`GetBinScriptPath esoreflex_set_memory`
  \sed "s|^ESOREFLEX_BASE=.*$|ESOREFLEX_BASE=\"${reflex_base_path}\"|g" "${script_path}" > "${script_path}.tmp"
  if [ $? -ne 0 ]; then
    echo ERROR: Failed to update the esoreflex_set_memory script.
    Cleanup
    exit 1
  fi
  \mv "${script_path}.tmp" "${script_path}"
  if [ $? -ne 0 ]; then
    echo ERROR: Failed to update the esoreflex_set_memory script.
    Cleanup
    exit 1
  fi
  \chmod 755 "${script_path}"
  if [ $? -ne 0 ]; then
    echo ERROR: Failed to update file mode bits for the esoreflex_set_memory script.
    Cleanup
    exit 1
  fi
}

# Configure the default directory that is used when the open file dialog pops up.
# This is done by uncommenting and setting the _alternateDefaultOpenDirectory
# property in the Kepler configuration.xml file.
#
UpdateDefaultOpenDirectory()
{
  local reflex_version=`cat "${download_dir}/reflex_version" | \
                        sed 's|^reflex-||' | sed 's|^esoreflex-||' | \
                        sed 's|-linux$||' | sed 's|-osx$||' | sed 's|-||g'`
  local major_version=`echo "${reflex_version}" | cut -d . -f 1`
  local minor_version=`echo "${reflex_version}" | cut -d . -f 2`
  if [ "${major_version}" -lt 2 -o \( "${major_version}" -eq 2 -a "${minor_version}" -lt 9 \) ] ; then
    local kepler_version="-2.4"
  elif [ "${major_version}" -eq 2 -a "${minor_version}" -lt 10 ] ; then
    local kepler_version="-2.5"
  else
    local kepler_version=""
  fi
  local config_file=`cat "${tempdir}/reflex_base_path"`"/common${kepler_version}/configs/ptolemy/configs/kepler/configuration.xml"
  local workflow_path="${installation_dir}/share/reflex/workflows"
  \sed "s|<\!--[[:space:]]*\(property[[:space:]][[:space:]]*name=\"_alternateDefaultOpenDirectory\"\).*|<\1 value=\"${workflow_path}\"|" "${config_file}" | \
    \sed "s|\(class[[:space:]]*=[[:space:]]*\"ptolemy[.]kernel[.]util[.]StringAttribute\"[[:space:]]*\)/[[:space:]]*-->|\1 />|" > "${config_file}.tmp"
  if [ $? -ne 0 ]; then
    echo ERROR: Failed to update default open file directory in configuration.xml.
    Cleanup
    exit 1
  fi
  \mv "${config_file}.tmp" "${config_file}"
  if [ $? -ne 0 ]; then
    echo ERROR: Failed to update default open file directory in configuration.xml.
    Cleanup
    exit 1
  fi
}

# Creates a link to the Reflex demo workflows path in share/reflex/workflows
#
AddLinkToDemoWorkflows()
{
  CreateDirectory "${installation_dir}/share/reflex/workflows"
  local reflex_base_path=`cat "${tempdir}/reflex_base_path"`
  local targetname=`basename "${reflex_base_path}"`
  \rm -f "${installation_dir}/share/reflex/workflows/${targetname}-demos"
  \ln -s "`GetEsoSubDir`/eso-demo-workflows" "${installation_dir}/share/reflex/workflows/${targetname}-demos"
  if [ $? -ne 0 ]; then
    echo ERROR: Failed to set link to demo Reflex workflows.
    Cleanup
    exit 1
  fi
}

InstallReflex()
{
  if [ -f "${tempdir}/reflex_to_install" ] ; then
    cd "${download_dir}"
    echo Installing Reflex...
    local reflex_local_file="${download_dir}"/`cat "${tempdir}/reflex_to_install"`.tar.gz
    if [ $offline -eq 0 ] ; then
      ${httpcommand} `cat "${tempdir}/reflex_package"` > /dev/null 2>&1
      if [ $? -ne 0 ]; then
        echo ERROR: Could not get Reflex package. Check disk space or permissions
        Cleanup
        exit 1
      fi
    else
      if [ ! -f $reflex_local_file ] ; then
        echo ERROR: The following file needed in offline mode is missing:
        echo ERROR: $reflex_local_file
        Cleanup
        exit 1
      fi
    fi
    cd "${installation_dir}"
    tar xzf $reflex_local_file -C "${installation_dir}"
    if [ $? -ne 0 ]; then
      echo ERROR: Could not install Reflex package. Check disk space or permissions
      Cleanup
      exit 1
    fi
    UpdateReflexBasePath
    PatchReflexVersionFile
    PatchLaunchScripts
    UpdateReflexCommand
    UpdateSetMemoryCommand
    UpdateDefaultOpenDirectory
    AddLinkToDemoWorkflows
  fi
}

InstallInstallationScript()
{
  CreateDirectory  "${installation_dir}/bin"
  cd "$tempdir"
  if [ $offline -eq 0 ] ; then
    ${httpcommand} https://www.eso.org/sci/software/pipelines/install_esoreflex > /dev/null 2>&1
    cp install_esoreflex "${installation_dir}/bin"
    chmod u+x "${installation_dir}/bin/install_esoreflex"
    cp install_esoreflex "${download_dir}"
  else
    if [ ! -f "${download_dir}"/install_esoreflex ] ; then
      echo ERROR: The following file needed in offline mode is missing:
      echo ERROR: "{$download_dir}"/install_esoreflex
      Cleanup
      exit 1
    fi
  fi
}

RemoveCurrentPipelines()
{
  if [ -f pipelines_to_install ] ; then
    echo Purging installed pipelines
    # Careful not to delete vltpipe_reflex_install path under etc/ since it
    # keeps a register of the installed pipelines and Reflex.
    for path_to_delete in "${installation_dir}"/etc/* ; do
      if [ "${path_to_delete}" != "${installation_dir}/etc/vltpipe_reflex_install" ] ; then
        rm -rf "${path_to_delete}"
      fi
    done
    \rm -rf "${installation_dir}/bin" "${installation_dir}/lib" "${installation_dir}/share" "${installation_dir}/calib" "${installation_dir}/include" "${installation_dir}/man"
  fi
}

RemoveCurrentReflex()
{
  if [ -f "${tempdir}/reflex_to_remove" ] ; then
    echo Purging installed Reflex `cat "${tempdir}/reflex_to_remove"`
    \rm -rf `cat "${tempdir}/reflex_path_to_remove"`
  fi
}

WriteDummyRecipeConfig()
{
  echo '# No default parameters should be specified for recipes under Reflex.' \
    > ${installation_dir}/etc/esoreflex_default_recipe_config.rc
}

WriteReflexCommand()
{
  local script_path=`GetBinScriptPath esoreflex`
  \rm -f "${installation_dir}/bin/esoreflex"
  \ln -s "${script_path}" "${installation_dir}/bin/esoreflex"
  if [ $? -ne 0 ]; then
    echo ERROR: Failed to install the esoreflex command.
    Cleanup
    exit 1
  fi
}

WriteSetMemoryCommand()
{
  local script_path=`GetBinScriptPath esoreflex_set_memory`
  \rm -f "${installation_dir}/bin/esoreflex_set_memory"
  \ln -s "${script_path}" "${installation_dir}/bin/esoreflex_set_memory"
  if [ $? -ne 0 ]; then
    echo ERROR: Failed to install the esoreflex_set_memory command.
    Cleanup
    exit 1
  fi
}

# This function checks to see if a path exists in a colon separated path list.
# 0 is returned if it does and 1 otherwise.
#   $1 - The path to find.
#   $2 - The list of paths to search.
#
PathExistsInPathList()
{
  # Save the field splitting characters and set it to a colon to split the
  # paths in $1.
  OLDIFS="$IFS"
  IFS=":"
  for N in $2 ; do
    if [ "$N" = "$1" ] ; then
      IFS="$OLDIFS"  # Restore field splitting character.
      return 0
    fi
  done
  IFS="$OLDIFS"  # Restore field splitting character.
  return 1
}

# Writes the default etc/esoreflex.rc file for the esoreflex launch command.
#
WriteEsoreflexConfig()
{
  local reflex_base_path=""
  if [ -f "${tempdir}/reflex_base_path" ] ; then
    reflex_base_path=`cat "${tempdir}/reflex_base_path"`
  else
    reflex_base_path=`cat "${installation_dir}/etc/vltpipe_reflex_install/installed_reflex_path"`
  fi

  esoreflex_python_path="${reflex_base_path}/esoreflex/python"
  if [ -n "$PYTHONPATH" ] ; then
    esoreflex_python_path="$esoreflex_python_path:$PYTHONPATH"
  fi

  local java_command=`command -v java`
  if [ $? -ne 0 ]; then
    echo ERROR: Could not find the location of the Java binary.
    Cleanup
    exit 1
  fi

  # Try find the directory to the python command and add it to the field
  # esoreflex.path in the configuration file if necessary, i.e. if it is
  # not already in the path list returned by getconf.
  if PathExistsInPathList `dirname ${python_command}` `getconf PATH` ; then
    local python_command_dir=""
  else
    local python_command_dir=:`dirname ${python_command}`
  fi

  local reflex_version=`cat "${download_dir}/reflex_version" | \
                        sed 's|^reflex-||' | sed 's|^esoreflex-||' | \
                        sed 's|-linux$||' | sed 's|-osx$||' | sed 's|-||g'`

  cat > "${installation_dir}/etc/esoreflex.rc" <<EOF
# This is the system wide configuration file for esoreflex ${reflex_version}.
# One can copy this file to ~/.esoreflex/esoreflex.rc and adjust these
# parameters appropriately for your customised environment if needed.
# However, if you do modify this file or use it with a different esoreflex
# version, it is possible it may not work properly. You will have to know what
# you are doing.

# TRUE/FALSE indicating if the user's environment should be inherited.
esoreflex.inherit-environment=FALSE

# The binary or command used to start Java.
esoreflex.java-command=${java_command}

# The search paths for workflows used by the launch script.
esoreflex.workflow-path=${installation_dir}/share/reflex/workflows:~/KeplerData/workflows/MyWorkflows

# The command used to launch esorex.
esoreflex.esorex-command=esorex

# The path to the esorex configuration file.
esoreflex.esorex-config=${installation_dir}/etc/esoreflex-esorex.rc

# The path to the dummy configuration file for recipes.
esoreflex.esorex-recipe-config=${installation_dir}/etc/esoreflex_default_recipe_config.rc

# The command used to launch python.
esoreflex.python-command=${python_command}

# Additional search paths for python modules. PYTHONPATH will be set to this
# value if esoreflex.inherit-environment=FALSE. However, the contents of
# esoreflex.python-path will be appended to any existing PYTHONPATH from the
# user's environment if esoreflex.inherit-environment=TRUE. Note that removing
# any paths that were added during the installation may break esoreflex.
esoreflex.python-path=${esoreflex_python_path}

# Additional search paths for binaries. This will be prepended to the default
# system PATH as returned by getconf if esoreflex.inherit-environment=FALSE.
# Otherwise the contents is appended to the user's PATH environment variable if
# esoreflex.inherit-environment=TRUE. Note that removing any paths that were
# added during the installation may break esoreflex.
esoreflex.path=${installation_dir}/bin${python_command_dir}

# Additional search paths for shared libraries. (DY)LD_LIBRARY_PATH will be set
# to this if esoreflex.inherit-environment=FALSE. However, the contents of
# esoreflex.library-path will be appended to any existing (DY)LD_LIBRARY_PATH
# variables from the user's environment if esoreflex.inherit-environment=TRUE.
# Note that removing any paths that were added during the installation may break
# esoreflex.
esoreflex.library-path=${installation_dir}/lib
EOF

  # Prepare the Python recipe directory for EsoReflex if it is missing and add
  # the path to a customised EsoRex configuration file.
  mkdir -p ${installation_dir}/share/reflex/recipes
  sed -e "s|\(esorex.caller.recipe-dir=.*\)|\1:${installation_dir}/share/reflex/recipes|" \
    ${installation_dir}/etc/esorex.rc > ${installation_dir}/etc/esoreflex-esorex.rc
}

HowToRunMessages()
{
  echo ==================================================================
  echo Run the following command to execute Reflex
  echo ${installation_dir}/bin/esoreflex
  echo You might want to define an alias for this command, e.g.
  echo For sh / bash / zsh:
  echo alias esoreflex=${installation_dir}/bin/esoreflex
  echo For csh / tcsh:
  echo alias esoreflex ${installation_dir}/bin/esoreflex
  echo To customize the memory Reflex will use, please run:
  echo ${installation_dir}/bin/esoreflex_set_memory
  echo ==================================================================
}

#Creates a temporary unique directory and stores its name in the
#variable name passed as first argument
MakeTempDir()
{
  local _tempdir=$1
  mytempdir=$(mktemp -d "$download_dir"/install_esoreflex_temp.XXXXXXXXXXXX) || { echo "ERROR creating a temporary directory" >&2; Cleanup; exit 1; }
  eval $_tempdir="'$mytempdir'"
}

#Remove completely the temporary directory.
RemoveTempDir()
{
  test -n "$tempdir" && \rm -rf "$tempdir"
}

#Remove the directories left by the install_pipelinekit script
RemoveInstallPipelineKitTempDir()
{
  test -n "${download_dir}" && \rm -rf "${download_dir}"/pipeline-kit-*tmp
}

#Check that the superset of python modules are available
#It tries both the python3 (prefered) and python2 stacks
CheckPythonCommandAndModules()
{
  cd "$tempdir"
  cat > python_check <<EOF
#Script to test the availability of the required modules
try:
  from astropy.io import fits as pyfits
except ImportError:
  import pyfits
import matplotlib
import matplotlib.backends.backend_wxagg
import wx
import optparse
import gettext
import types, re, sys
import math
EOF
  chmod u+x python_check

  #Prefer python3 over python2
  #The python_command is used later on to write the configuration file
  python_command=`command -v python3`
  python3_found=$?
  if [ $python3_found -eq 0 ] ; then
    $python_command ./python_check 2>/dev/null
    python3_modules_found=$?
  fi
  if [ "$python3_found" -ne 0 ] || [ "$python3_modules_found" -ne 0 ] ; then
    echo WARNING: Your python3 environment does not seem to have all needed Python modules.
    echo WARNING: Trying python2 environment...
    python_command=`command -v python2`
    python2_found=$?
    if [ "$python2_found" -ne 0 ] && [ "$python3_found" -ne 0 ]; then
      echo WARNING: No python2 or python3 commands found.
      echo WARNING: Some pipeline workflows might require them.
      echo
      printf "Do you want to continue anyway? [y/N] "
      read -r proceed
      proceed=`echo $proceed | tr '[:upper:]' '[:lower:]'`
      if [ ! "x$proceed" = "xy" ] ; then
        echo Aborting
        Cleanup
        exit 1
      fi
    else
      $python_command ./python_check 2>/dev/null
      if [ ! $? -eq 0 ] ; then
        echo WARNING: Some Python modules are not installed in your system
        echo WARNING: The following script has been used to test for those modules:
        echo =============
        cat ./python_check
        echo =============
        echo WARNING: Some pipeline workflows might require them those modules.
        if [ $python3_found -eq 0 ] ; then
          echo WARNING: The python3 environment used was `command -v python3`
        else
          echo WARNING: No python3 environment has been found
        fi
        if [ $python2_found -eq 0 ] ; then
          echo WARNING: The python2 environment used was `command -v python2`
        else
          echo WARNING: No python2 environment has been found
        fi

        echo
        printf "Do you want to continue anyway? [y/N] "
        read -r proceed
        proceed=`echo $proceed | tr '[:upper:]' '[:lower:]'`
        if [ ! "x$proceed" = "xy" ] ; then
          echo Aborting
          Cleanup
          exit 1
        fi
      fi
    fi
  fi
}

#Check that java is installed
CheckJava()
{
  CheckCommandExist java
  echo
  echo "Please make sure you have a compatible Java JRE installed."
  echo "Versions 8 to 11 are supported by Reflex."
  echo
}

GetScriptOptions()
{
  #Default release channel
  release_channel=stable
  while getopts "d:i:s:r:h" option_name; do
    case "$option_name" in
      d) download_dir="$OPTARG";;
      i) installation_dir="$OPTARG";;
      s) dataset_dir="$OPTARG";;
      r) release_channel="$OPTARG";;
      h) PrintUsageAndExit;;
      [?]) PrintUsageAndExit ;;
    esac
  done
}

PrintUsageAndExit()
{
  version=`echo \$Revision: 280466 $ | cut -f 2 -d' '`
  echo This is the $0 script to install Reflex. Version $version
  echo This script allows to install Reflex together with pipelines
  echo with Reflex workflows support. It retrieves the latest versions
  echo of the pipelines from the ESO servers. An offline mode also exists.
  echo Please follow the instructions that appear in the screen.
  echo
  echo "Usage: $0 [-d DOWNLOAD_DIR] [-i INSTALL_DIR] [-s DATA_DIR] [-h]"
  echo
  echo "       -d DOWNLOAD_DIR  The directory where to download all the data."
  echo "                        If not given, the script will ask"
  echo "       -i INSTALL_DIR   The directory where to install the software,"
  echo "                        including Reflex and the pipelines."
  echo "                        If not given, the script will ask"
  echo "       -s DATA_DIR      The directory where to download all the data."
  echo "                        The products of the pipeline, logs and"
  echo "                        bookkeeping will also be stored here."
  echo "                        If not given, the script will ask"
  echo "                        If not given, the script will ask"
  echo
  echo " Example: install_esoreflex -d d_dir -i i_dir -s d_dir"

  Cleanup
  exit 1
}

#Get the name of the directories
GetConfigDirectories()
{
  if [ -z "$download_dir" ] ; then
    printf "Input directory for temporary downloaded files (> 500 Mb) [download_reflex]: "
    read -r download_dir
    if [ -z "$download_dir" ] ; then
      download_dir="download_reflex"
    fi
  fi
  test `pwd` -ef $download_dir
  if [ $? -eq 0 ] ; then
    echo "ERROR: The download dir is the same as current one. Choose other"
    Cleanup
    exit 1
  fi
  if [ -z "$installation_dir" ] ; then
    printf "Input directory for installation of all software  (> 500 Mb) [install]: "
    read -r installation_dir
    if [ -z "$installation_dir" ] ; then
      installation_dir="install"
    fi
  fi
  echo NOTE: The default ROOT_DATA_DIR for installed workflows is set to \$HOME/reflex_data
  if [ -z "$dataset_dir" ] ; then
    printf "Input directory for installation of demo datasets (variable size) [data_wkf]: "
    read -r dataset_dir
    if [ -z "$dataset_dir" ] ; then
      dataset_dir="data_wkf"
    fi
  fi

  if [ ! -d "${download_dir}" ] ; then
    CreateDirectory "${download_dir}"
  fi
  if [ ! -d "${installation_dir}" ] ; then
    CreateDirectory "${installation_dir}"
  fi
  if [ ! -d "${dataset_dir}" ] ; then
    CreateDirectory "${dataset_dir}"
  fi
  local base_dir=$PWD
  cd "${base_dir}"
  cd "${download_dir}"
  download_dir=${PWD}
  cd "${base_dir}"
  cd "${installation_dir}"
  installation_dir=${PWD}
  cd "${base_dir}"
  cd "${dataset_dir}"
  dataset_dir=${PWD}
  if [ "${download_dir}" = "${installation_dir}" ] ; then
    # If the download dir is the same as the installation directory this will
    # not work. Therefore we create a subdirectory within the installation path
    # instead for this case (PIPE-6954).
    download_dir="${installation_dir}/download"
    CreateDirectory "${download_dir}"
  fi

  echo Using the following directory configuration
  echo Download directory: ${download_dir}
  echo Installation directory: ${installation_dir}
  echo Demo dataset directory: ${dataset_dir}
  echo
}

GetReleaseChannel()
{
  if [ "$release_channel" != "stable" ] &&  [ "$release_channel" != "testing" ] &&  [ "$release_channel" != "devel" ] &&  [ "$release_channel" != "legacy" ] ; then
    echo Unknown release channel $release_channel
    Cleanup
    exit 1
  fi
  if [ "$release_channel" != "stable" ] ; then
    echo Using release channel $release_channel
  fi
}

CreateDirectory()
{
  echo "Creating dir '$1'"
  mkdir -p "$1" > /dev/null 2> /dev/null
  retval=$?
  if [ $retval -ne 0 ]; then
    echo ERROR: Could not create dir $1. Verify path or permissions
    Cleanup
    exit 1
  fi
}

#Check if a command is in the path
CheckCommandExist()
{
  exec_com=$1
  command -v $exec_com > /dev/null 2> /dev/null
  local retval=$?
  if [ $retval -ne 0 ]; then
    echo ERROR: $exec_com is not installed in your system.
    Cleanup
    exit 1
  fi
}

#Check that the needed programas are in the path
CheckTextUtils()
{
  CheckCommandExist awk
  CheckCommandExist tr
  CheckCommandExist cat
  CheckCommandExist sed
  CheckCommandExist grep
  CheckCommandExist mkdir
  CheckCommandExist rm
  CheckCommandExist cksum
  CheckCommandExist basename
  CheckCommandExist touch
  CheckCommandExist perl
}

#Get the command used to retrieve web pages. It can be wget or curl
GetHttpCommand()
{
  local _httpcommand=$1
  command -v wget > /dev/null 2> /dev/null
  retval=$?
  if [ $retval -ne 0 ]; then
    command -v curl > /dev/null 2> /dev/null
    retval=$?
    if [ $retval -ne 0 ]; then
      echo ERROR: Neither wget or curl are installed. Please install them.
      Cleanup
      exit 1
    else
      local myhttpcommand='curl -O -L -C -'
    fi
  else
    local myhttpcommand='wget -c'
  fi
  eval $_httpcommand="'$myhttpcommand'"
}

# This has to be calculated here, before and change of directory to get the
# correct path of the script in case $0 is a relative path.
current_revision=`grep '\$Revision' "$0" 2> /dev/null | sed -e 's|^.*\$Revision: \([[:digit:]]*\).*$|\1|' 2> /dev/null`

# Check if there is a newer version of this script and alert the user.
CheckForNewerScriptVersion()
{
  if [ $offline -eq 0 ] ; then
    local topdir=`pwd`
    cd "${tempdir}"
    ${httpcommand} https://www.eso.org/sci/software/pipelines/install_esoreflex > /dev/null 2>&1
    if [ $? -eq 0 ]; then
      local new_revision=`grep '\$Revision' install_esoreflex 2> /dev/null | sed -e 's|^.*\$Revision: \([[:digit:]]*\).*$|\1|' 2> /dev/null`
      if [ "$new_revision" -gt "$current_revision" ] 2> /dev/null; then
        echo
        echo "A newer version of the current script is available on the FTP server."
        echo "It is recommended to use the newer version. It can be downloaded from:"
        echo "    https://www.eso.org/sci/software/pipelines/install_esoreflex"
        printf "Do you want to continue using the older script [y/N]? "
        read -r proceed
        proceed=`echo $proceed | tr '[:upper:]' '[:lower:]'`
        if [ "x$proceed" != "xy" ] ; then
          Cleanup
          exit 0
        fi
      fi
    fi
    cd "${topdir}"
  fi
}

PrintWelcome()
{
  echo ======================================================================
  echo "  Welcome to the installation script for Reflex and pipeline workflows"
  echo ======================================================================
}

ReplaceWorkflowDataPath()
{
  #Do this only if pipelines have been installed
  if [ -f "${tempdir}/pipelines_to_install" ] ; then

    # replace data dir in the workflows
    # Note that we are performing the replacement to be more consistent with how
    # RPM and MacPorts installations work (PIPE-8250).
    find "${installation_dir}/share/reflex/workflows" -name "*.xml" -exec sh -c 'file="{}" ; sed "s%ROOT_DATA_PATH_TO_REPLACE%\$HOME/reflex_data%g" "$file"  > "$file.edit" ; mv "$file.edit" "$file" ' \;
    find "${installation_dir}/share/esopipes" -name "*.xml" -exec sh -c 'file="{}" ; sed "s%ROOT_DATA_PATH_TO_REPLACE%\$HOME/reflex_data%g" "$file"  > "$file.edit" ; mv "$file.edit" "$file" ' \;
    find "${installation_dir}/share/reflex/workflows" -name "*.xml" -exec sh -c 'file="{}" ; pipename=$(echo $file | sed "s%.*/share/reflex/workflows/\([^-]*\).*%\1%") ; sed "s%\(<property name=\"RAW_DATA_DIR\" class=\"ptolemy\.data\.expr\.FileParameter\" value=\"\).*\">%\1'${dataset_dir}'/reflex_input/$pipename\">%g" "$file"  > "$file.edit" ; mv "$file.edit" "$file" ' \;
    find "${installation_dir}/share/esopipes" -name "*.xml" -exec sh -c 'file="{}" ; pipename=$(echo $file | sed "s%.*/share/esopipes/\([^-]*\).*%\1%") ; sed "s%\(<property name=\"RAW_DATA_DIR\" class=\"ptolemy\.data\.expr\.FileParameter\" value=\"\).*\">%\1'${dataset_dir}'/reflex_input/$pipename\">%g" "$file"  > "$file.edit" ; mv "$file.edit" "$file" ' \;
    # The following is for workflows that did not move to the new RAW_DATA_DIR standard.
    find "${installation_dir}/share/reflex/workflows" -name "*.xml" -exec sh -c 'file="{}" ; pipename=$(echo $file | sed "s%.*/share/reflex/workflows/\([^-]*\).*%\1%") ; sed "s%\(<property name=\"RAWDATA_DIR\" class=\"ptolemy\.data\.expr\.FileParameter\" value=\"\).*\">%\1'${dataset_dir}'/reflex_input/$pipename\">%g" "$file"  > "$file.edit" ; mv "$file.edit" "$file" ' \;
    find "${installation_dir}/share/esopipes" -name "*.xml" -exec sh -c 'file="{}" ; pipename=$(echo $file | sed "s%.*/share/esopipes/\([^-]*\).*%\1%") ; sed "s%\(<property name=\"RAWDATA_DIR\" class=\"ptolemy\.data\.expr\.FileParameter\" value=\"\).*\">%\1'${dataset_dir}'/reflex_input/$pipename\">%g" "$file"  > "$file.edit" ; mv "$file.edit" "$file" ' \;

    # replace calib dir in the workflows
    find "${installation_dir}/share/reflex/workflows" -name "*.xml" -exec sh -c 'file="{}" ; sed "s%CALIB_DATA_PATH_TO_REPLACE%'${installation_dir}/share/esopipes/datastatic'%g" "$file"  > "$file.edit" ; mv "$file.edit" "$file" ' \;
    find "${installation_dir}/share/esopipes" -name "*.xml" -exec sh -c 'file="{}" ; sed "s%CALIB_DATA_PATH_TO_REPLACE%'${installation_dir}/share/esopipes/datastatic'%g" "$file"  > "$file.edit" ; mv "$file.edit" "$file" ' \;

  fi
}

RemoveKeplerDataESO()
{
  if [ -d $HOME/KeplerData/modules/esoreflex ] ; then
    echo WARNING: The installation has detected the following directory:
    echo WARNING: $HOME/KeplerData/modules/esoreflex
    echo WARNING: This means that a previous installation of Reflex
    echo WARNING: existed, which is known to gives problems in some cases.
    echo WARNING: Additionally, the $HOME/.kepler,
    echo WARNING: $HOME/KeplerData/kepler.modules and $HOME/KeplerData/MyData
    echo WARNING: directories should also be removed.
    printf "Do you want to delete these directories [Y/n]? "
    read -r proceed
    proceed=`echo $proceed | tr '[:upper:]' '[:lower:]'`
    if [ "x$proceed" = "xn" ] ; then
      echo $HOME/KeplerData has been kept
    else
      \rm -rf $HOME/KeplerData/modules
      \rm -rf $HOME/KeplerData/kepler.modules
      \rm -rf $HOME/KeplerData/MyData
      \rm -rf $HOME/.kepler
      echo $HOME/KeplerData and $HOME/.kepler have been removed
    fi
  fi
}

# Offer to move existing ~/.esoreflex/esoreflex.rc file to a backup copy if it
# exists so that the config installed with this script takes precedence.
#
RemoveEsoreflexrcFromHome()
{
  if [ -f ~/.esoreflex/esoreflex.rc ] ; then
    echo WARNING: The configuration file "~/.esoreflex/esoreflex.rc" already exists.
    echo WARNING: This will take precedence over the Reflex configuration file shipped
    echo WARNING: with this installation.
    printf "Do you want to move this file so that it does not get used [Y/n]? "
    read -r proceed
    proceed=`echo $proceed | tr '[:upper:]' '[:lower:]'`
    if [ "x$proceed" = "xn" ] ; then
      echo "~/.esoreflex/esoreflex.rc" will be used for the Reflex configuration.
    else
      suffix=""
      while [ -f ~/.esoreflex/esoreflex.rc.backup"${suffix}" ] ; do
        if [ -z "${suffix}" ] ; then
          suffix=1
        else
          suffix=$(($suffix+1))
        fi
      done
      \mv ~/.esoreflex/esoreflex.rc ~/.esoreflex/esoreflex.rc.backup"${suffix}"
      echo "~/.esoreflex/esoreflex.rc" moved to "~/.esoreflex/esoreflex.rc.backup${suffix}"
    fi
  fi
}

Cleanup()
{
  RemoveTempDir
  RemoveInstallPipelineKitTempDir
}

InstallationInterrupted()
{
  echo
  echo Installation interrupted
  Cleanup
  exit 1
}

PrintWelcome
GetScriptOptions $@
GetConfigDirectories
AskOffline
GetReleaseChannel
MakeTempDir tempdir
GetHttpCommand httpcommand
CheckForNewerScriptVersion
CheckJava
CheckTextUtils
CheckPythonCommandAndModules
GetAvailableReflexVersion
GetAvailablePipelines
GetInstalledReflex
GetInstalledPipelines
GetReflexToInstall
GetPipelinesToInstall
GetPipelineDemoDataToInstall
ConfirmInstallation
RemoveCurrentPipelines
RemoveCurrentReflex
InstallPipelines
InstallReflex
InstallInstallationScript
WriteDummyRecipeConfig
WriteEsoreflexConfig
WriteReflexCommand
ReplaceWorkflowDataPath
WriteInstalledPackagesConfiguration
RemoveKeplerDataESO
RemoveEsoreflexrcFromHome
WriteSetMemoryCommand
HowToRunMessages
Cleanup
exit
