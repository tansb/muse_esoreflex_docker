# How to do the painful task of installing the MUSE pipeline to run in a docker container.

I've created a dockerfile and docker-compose file that installs the esoreflex MUSE pipeline along with its demo data. These instructions are for macs with M1 chips (ARM64). I've also tested it on a AMD64 computer running ubuntu, where I just didn't have do step 2.

## 1. Set the mount point for the docker container
Docker containers are designed to work and operate in isolation, but when using esoreflex you need an easy way to pass data in and out. Therefore, specify a directory to mount into the container so you can access that data from within the container (and save the reduced files out).

```export MY_MOUNTED_DATA_DIR=<your_data_dir>```

## 2. Build the Docker Image

cd to the directory with the Dockerfile and the docker-compose.yml file. Do:
```docker compose up -d```

In this docker image, I have included a modified version of the install_reflex bash script. The [standard script from eso](https://www.eso.org/sci/software/pipelines/install_esoreflex) has a prompt asking which pipelines to install, in which the default response downloads ALL pipelines with ALL demo data. This would not only take forever to download and install, but causes issues with docker container storage limits. From past experience even 3 pipelines reached storage limits. There are ways around this but it seemed more straightforward to have an image per pipeline.

The dockerfile runs in non-interactive mode. Therefore, to stop the dockerfile from using the default prompt and installing all the pipelines I modified the install_esoreflex script to not prompt for which pipelines to install. Instead the script just installs MUSE (number 16). Ive put the modified script on [github](https://github.com/tansb/muse_esoreflex_docker/blob/main/install_esoreflex_muse_only.sh) so the dockerfile can download it via curl.

It will take a while to download the MUSE data (30 mins?), so go get a snack while you wait.

## 2. Set up X11 forwarding to XQuartz

Esoreflex is a GUI, so you need some way to forward the display from the container to your actual laptop's display.

### (a): Allow X11 access

-   Open XQuartz and go to `Preferences` \> `Security`. Make sure "**Allow connections from network clients**" is enabled.

-   Also, on your mac run the command ```xhost +``` to allow the Docker container to connect to any X11 server.

## 3. Enter the Docker Container

```docker exec -it esoreflex_muse_container bash```

Test that the X11 forwarding is working correctly by typing ```xclock``` into the container terminal. A little clock should open in XQuartz. If not, not sure try step 2 again?

## 4. Run ESOReflex

In the container terminal type `esoreflex` and voila! The Kepler GUI should open in XQuartz.

# Side notes:

## A. Modified install_esoreflex file

How did I modify the install_esoreflex to not prompt for which pipelines to install and just install the MUSE pipeline? I replaced this section of the install_esoreflex script:

``` {.bash style="color"}
GetPipelinesToInstall()
{
  cd "${tempdir}"
  echo ==================================================================
  echo The following list contains the latest available versions of
  echo pipelines with workflows published by the VLT pipelines team
  echo Please specify ALL the pipelines you want to install.
  ...
  while :
  do
    printf  "Input PipeIDs for pipelines to install [A]: "
    read -r pipeline_numbers_to_install
    ...
  done
}
```

with

``` {.bash style="color"}
GetPipelinesToInstall()
{
  cd "${tempdir}"
  echo ==================================================================
  echo "File edited by tansb! Automatically selected MUSE pipeline for install"
  echo ==================================================================

  # Clear existing pipelines_to_install file
  \rm -f pipelines_to_install

  # Add MUSE pipeline (assuming PipeID 16 corresponds to MUSE)
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
```

I have put this here in case you want to do it for another pipeline in the future. You should just be able to change the number 16 in line 93:

```awk '{if (NR == 16) printf("%s %s\n", $1, $2)}'```

to the number corresponding to the pipeline you want to install. NOTE this hasn't been tested, because different pipelines have different dependencies, so you will likely need to slightly modify the Dockerfile as well

## B. Commit updated container to a new image

If you've made substantial changes to a container from its original image, you may want to save the current container to a new image so it can be easily recreated. To commit a container to a new image follow the below steps. *Containers are ephemeral, images are forever.*

First do:

`docker ps -a`

To print a list of all the containers and get the container ID of the container you want to save. Then do

`docker commit <container_ID> <username/image_name:tag>`

e.g.

`docker commit d5cc5c0be09a tbar/esoreflex_muse:testcommit`

OK! now all your hard work in that container is saved.