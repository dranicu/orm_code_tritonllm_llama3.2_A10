# **ORM_stack_tritonllm_llama3.2_models_a10_shape**

# **ORM Stack to deploy an A10* shape with one GPU to test NVIDIA tritonllm inference for llama3.2_models*

- [Instalation](#instalation)
- [Note](#note)
- [System monitoring](#system-monitoring)
- [Test Tritonllm](#test-triton)


## Instalation

This stack deploys [**NVIDIA Triton LLM Inference Server with different Llama3.2 models**](https://www.infracloud.io/blogs/running-llama-3-with-triton-tensorrt-llm/) on an A10 shape instance in OCI:

- once the instance is created, wait the cloud init completion and then you can test interaction with the model in this way [Test Tritonllm](#test-triton)


## NOTE
- **the code deploys an A10 shape with one or more GPUs**
- **based on your need you have the option to either create a new VCN and subnet or you can use an existing VCN and a subnet where the VM will be deployed**
- **it will add a freeform TAG : "GPU_TAG"= "A10-1"**
- **the boot vol is 500 GB**
- **the cloudinit will do all the steps needed to pull the tritonllm docker image and to start the inference interface**
- **in case you create your instance in a public subnet you can query Triton_Inference_Server via its instance public IP**

## System monitoring
- **Some commands to check the progress of cloudinit completion and GPU resource utilization:**
```
monitor cloud init completion: tail -f /var/log/cloud-init-output.log
monitor for a single GPU shape: nvidia-smi dmon -s mu -c 100
                                watch -n 2 'nvidia-smi'
monitor the system in general: sar 3 1000
```
## Allow_access for Triton_Inference if you used public IP
### Enable access to Triton_Inference on both Oracle Linux and Ubuntu for public IP test:

- **Oracle Linux:**

```
sudo firewall-cmd --zone=public --permanent --add-port 8000/tcp
sudo firewall-cmd --reload
sudo firewall-cmd --list-all
```

- **Ubuntu:**

```
sudo iptables -L
sudo iptables -F
sudo iptables-save > /dev/null
```
If this does not work do also this:
```
sudo systemctl stop iptables
sudo systemctl disable iptables

sudo systemctl stop netfilter-persistent
sudo systemctl disable netfilter-persistent

sudo iptables -F
sudo iptables-save > /dev/null
```
## Test triton
## Test_tritonllm from the created instance (once the cloudinit completes)
```
curl -X POST http://localhost:8000/v2/models/ensemble/generate -d   '{"text_input": "What is machine learning?", "max_tokens": 20, "bad_words": "", "stop_words": ""}'
```
## Test_tritonllm from the created instance (once the cloudinit completes and firewall rule permits the acces)
```
curl -X POST http://<instance_public_ip>:8000/v2/models/ensemble/generate -d   '{"text_input": "What is machine learning?", "max_tokens": 20, "bad_words": "", "stop_words": ""}'
```
