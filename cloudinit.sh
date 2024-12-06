#!/bin/bash

echo "running cloudinit.sh script"

region=`curl -s -H "Authorization: Bearer Oracle" -L http://169.254.169.254/opc/v2/instance/regionInfo/regionIdentifier`
model_engine=`curl -s -H "Authorization: Bearer Oracle" -L http://169.254.169.254/opc/v2/instance/metadata/model_engine`


echo "export REGION=\"$region\"" >> /home/opc/.bashrc
echo "export model_engine=\"$model_engine\"" >> /home/opc/.bashrc

dnf install -y dnf-utils zip unzip gcc
dnf config-manager --add-repo=https://download.docker.com/linux/centos/docker-ce.repo
dnf remove -y runc

echo "INSTALL DOCKER"
dnf install -y docker-ce --nobest

echo "ENABLE DOCKER"
systemctl enable docker.service

echo "INSTALL NVIDIA CONT TOOLKIT"
dnf install -y nvidia-container-toolkit

echo "START DOCKER"
systemctl start docker.service

echo "PYTHON packages"
python3 -m pip install --upgrade pip wheel oci
python3 -m pip install --upgrade setuptools
python3 -m pip install oci-cli
python3 -m pip install langchain
python3 -m pip install python-multipart
python3 -m pip install pypdf
python3 -m pip install six

echo "GROWFS"
/usr/libexec/oci-growfs -y


echo "Export nvcc"
sudo -u opc bash -c 'echo "export PATH=\$PATH:/usr/local/cuda/bin" >> /home/opc/.bashrc'
sudo -u opc bash -c 'echo "export LD_LIBRARY_PATH=\$LD_LIBRARY_PATH:/usr/local/cuda/lib64" >> /home/opc/.bashrc'

echo "Add docker opc"
usermod -aG docker opc

echo "CUDA toolkit"
dnf config-manager --add-repo https://developer.download.nvidia.com/compute/cuda/repos/rhel8/x86_64/cuda-rhel8.repo
dnf clean all
dnf -y install cuda-toolkit-12-4
dnf -y install cudnn

echo "Python 3.10.6"
dnf install curl gcc openssl-devel bzip2-devel libffi-devel zlib-devel wget make sqlite-devel -y
wget https://www.python.org/ftp/python/3.10.6/Python-3.10.6.tar.xz
tar -xf Python-3.10.6.tar.xz
cd Python-3.10.6/
./configure --enable-optimizations
make -j $(nproc)
sudo make altinstall
python3.10 -V
cd ..
rm -rf Python-3.10.6*

echo "Git"
dnf install -y git

echo "Pulling docker image"
su - opc -c "source /home/opc/.bashrc && docker pull fra.ocir.io/ocisateam/tritonllm_llama3.2:latest"

echo "Starting the docker container"
su - opc -c "nohup docker run --rm \
  --net host \
  --shm-size=2g \
  --ulimit memlock=-1 \
  --ulimit stack=67108864 \
  --gpus all \
  --cap-add SYS_ADMIN \
  --device /dev/fuse \
  --security-opt apparmor=unconfined \
  -e engine=$model_engine \
  fra.ocir.io/ocisateam/tritonllm_llama3.2:latest > ~opc/docker_container.log 2>&1 &"


date