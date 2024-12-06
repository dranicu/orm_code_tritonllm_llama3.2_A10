#!/bin/bash

echo "running cloudinit.sh script"

region=`curl -s -H "Authorization: Bearer Oracle" -L http://169.254.169.254/opc/v2/instance/regionInfo/regionIdentifier`
model_engine=`curl -s -H "Authorization: Bearer Oracle" -L http://169.254.169.254/opc/v2/instance/metadata/model_engine`


echo "export REGION=\"$region\"" >> /home/ubuntu/.bashrc
echo "export model_engine=\"$model_engine\"" >> /home/ubuntu/.bashrc

apt-get update -y
apt-get install -y dnf-utils zip unzip gcc curl openssl libssl-dev libbz2-dev libffi-dev zlib1g-dev wget make git

echo "INSTALL NVIDIA CUDA + TOOLKIT + drivers"
wget https://developer.download.nvidia.com/compute/cuda/repos/ubuntu2404/x86_64/cuda-keyring_1.1-1_all.deb
dpkg -i cuda-keyring_1.1-1_all.deb
apt-get update -y
apt-get -y install cuda-toolkit-12-5
apt-get install -y nvidia-driver-555
apt-get -y install cudnn
curl -fsSL https://nvidia.github.io/libnvidia-container/gpgkey | sudo gpg --dearmor -o /usr/share/keyrings/nvidia-container-toolkit-keyring.gpg \
  && curl -s -L https://nvidia.github.io/libnvidia-container/stable/deb/nvidia-container-toolkit.list | \
    sed 's#deb https://#deb [signed-by=/usr/share/keyrings/nvidia-container-toolkit-keyring.gpg] https://#g' | \
    sudo tee /etc/apt/sources.list.d/nvidia-container-toolkit.list
apt-get update
apt-get install -y nvidia-container-toolkit

echo "Add Docker repository and install Docker"
apt-get remove -y runc
apt-get install -y \
    apt-transport-https \
    ca-certificates \
    curl \
    gnupg \
    lsb-release
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
echo \
    "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu \
    $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
apt-get update -y
apt-get install -y docker-ce docker-ce-cli containerd.io

echo "ENABLE DOCKER"
systemctl enable docker.service

echo "START DOCKER"
systemctl start docker.service


echo "PYTHON packages"
apt-get install -y python3-pip
python3 -m pip install --upgrade pip wheel oci
python3 -m pip install --upgrade setuptools
python3 -m pip install oci-cli langchain python-multipart pypdf six

echo "GROWFS"
growpart /dev/sda 1
resize2fs /dev/sda1

echo "Export nvcc"
echo "export PATH=\$PATH:/usr/local/cuda/bin" >> /home/ubuntu/.bashrc
echo "export LD_LIBRARY_PATH=\$LD_LIBRARY_PATH:/usr/local/cuda/lib64" >> /home/ubuntu/.bashrc

echo "Add docker ubuntu"
usermod -aG docker ubuntu

echo "Python 3.10.6"
wget https://www.python.org/ftp/python/3.10.6/Python-3.10.6.tar.xz
tar -xf Python-3.10.6.tar.xz
cd Python-3.10.6/
./configure --enable-optimizations
make -j $(nproc)
make altinstall
python3.10 -V
cd ..
rm -rf Python-3.10.6*

echo "Git"
apt-get install -y git

echo "Installing unzip"
apt install unzip


echo "Pulling docker image"
su - ubuntu -c "source /home/ubuntu/.bashrc && docker pull fra.ocir.io/ocisateam/tritonllm_llama3.2:latest"

echo "Starting the docker container"
su - ubuntu -c "nohup docker run --rm \
  --net host \
  --shm-size=2g \
  --ulimit memlock=-1 \
  --ulimit stack=67108864 \
  --gpus all \
  --cap-add SYS_ADMIN \
  --device /dev/fuse \
  --security-opt apparmor=unconfined \
  -e engine=$model_engine \
  fra.ocir.io/ocisateam/tritonllm_llama3.2:latest > ~ubuntu/docker_container.log 2>&1 &"


su - ubuntu -c "sudo nvidia-smi"
date