## Quick Start Guide for `startup_script.sh`

### What It Does
The `script.sh` is your go-to for launching a Minikube-based Kubernetes environment for the deel app. It's like a magic wand for setting up `kubectl`, `helm`, Minikube, and other key components like Redis and Nginx Ingress. Plus, it tweaks your hosts file for easy access to your deployed services.

### Need to Know
- **OS Compatibility**: Works best on Linux (Ubuntu 22.04 is a charm!). macOS users, be cautious – it gave my ThinkPad a tough time so I didn't fully test it on a mac.
- **User Permissions**: Run it as a normal user, but make sure you've got sudo access.
- **Tools on Deck**: It'll get you Docker, kubectl, Minikube, helm. 

### How to Run
1. Make the script executable: `chmod +x script.sh`.
2. Fire it up: `./script.sh`.
3. No need for root or direct sudo – it knows its way around permissions.
4. Should `docker` be installed by the script, the script would exit prompting you to log your user out and log back in before firing up the script again.
5. Then point your browser to `deel-app.local` to see everything in action.
6. After running you can destroy the cluster by running `minikube delete -p deel`

### Caution
Running this with root might mix up Minikube and kubectl's home settings and muddle cluster credentials. 

### Future Plans
- Auto-certificate management with cert-manager - for https.
- Vault for rotating Redis secrets safely.
- Open policy agent to guard deployment access.
- Image policy webhook, network policies, and container runtime security to container access.

As the saying goes, being early in the market beats waiting for perfection. I would get this before the interview stage with the hiring manager. Also, if you would like to indulge me I would write a blog about the challenges i have faced while trying to add more features to this and also how I overcame them - I kept pulling my hair at falco 😉

#### TODO:
* make the app run using goroutine
* comprehensive test on local cluster
* comprehensive test on gcp with a domain
* ensure you use certificates - jetstack
* set up cd for the application - argocd
* comprehensive test for ci
* add monitoring and alerting for application. Also set up liveness and readiness check
* set up container runtime security - either implement falco, and some capabilities and seccomp stuff.
* create infrastructure using terraform for gcp quick set up
* update readme with the following topics - gcp, essence of script, cicd - argocd - and etc.
