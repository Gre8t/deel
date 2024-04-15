## Quick Start Guide for `Deel App`
The Deel app is built using Golang and uses github actions as it's CI pipeline while utilizing the mighy ArgoCD for CD purposes.

## About the app
The app is built as a docker container and packaged as helm chart while being deployed - managed by argocd. The chart is located in this directory - `./deel`
* **Tunneling** - previously used Ngrok, but the free version was limited to just one domain and no subdomain. Decided to switch to cloudflare Argo Tunnelling.
* **Deel Application** - the application itself can only detect internal IP address of our cloudflare tunnel service. This is because tunnels do not have features like nginx ingress controller that can forward the origin ip address to the Server
* **Secret replication** - it would be wise to replicate the redis secret in to the staging environment instead of using some complicated scripting logic to update the secret manifest in the deel helm chart. Though this is not safe, but for the level of development I have reached and the time resource available it is the best option to glue everything together. As we progress I would likely implement Hashicorp `Vault`
* **Falco** - this is for security, it is mean't to monitor the application and ensure that an authorized process doesn't run. If it does run it should send a message to prometheus
* **Redis** - This was decided as the db for the application because of it's caching capabilities, considering the fact that most users use a static ip address.
* **Prometheus** - Still a WIP, but it's importance can not be understated. It is needed to gather threat information from falco. And, at the same time it is the birds eye view of everything going on in the cluster - observability.
* **ArgoCD** - Although, it is best practice to have the application helm chart seperate from the code, I decided to put everything in one repo for ease of management and sharing.
### Need to Know
- **OS Compatibility**: Works best on Linux (Ubuntu 22.04 is a charm!). macOS users, be cautious – it gave my ThinkPad a tough time so I didn't fully test it on a mac.
- **User Permissions**: Run it as a normal user, but make sure you've got sudo access.
- **Tools on Deck**: It'll get you Docker, kubectl, Minikube and helm. 

### How to Run
The `script.sh` is your go-to for launching a Minikube-based Kubernetes environment for the deel app. It's like a magic wand for setting up `kubectl`, `helm`, Minikube, and other key components like Redis and cloudflare tunnel.

1. Make the script.sh file executable: `chmod +x ./script.sh`.
2. Fire it up: `./script.sh`.
3. No need for root or direct sudo – it knows its way around permissions.
4. Then point your browser to `deel.greatnessdomain.xyz` to see everything in action.
5. You can also visit `ci.greatnessdomain.xzy` to see argocd in action. The password would be given to you when you run the script.
6. Still a wip, but you can visit `observability.greatnessdomain.xyz` to see what is going on with the application and the cluster.
7. After running you can destroy the cluster by running `minikube delete -p deel`


### Caution
Running this with root might mix up Minikube and kubectl's home settings and muddle cluster credentials. 

### Future Plans
- Vault for rotating Redis secrets safely.
- Open policy agent to guard deployment access.
- Image policy webhook, network policies, and container runtime security to container access.
- add monitoring and alerting for application. Also set up liveness and readiness check
- create infrastructure using terraform for gcp quick set up
- update readme with the following topics - gcp, essence of script, cicd - argocd 

As the saying goes, being early in the market beats waiting for perfection. I would get this done before the interview stage with the hiring manager. Also, if you would like to indulge me I would write a blog about the challenges i have faced while trying to add more features to this and also how I overcame them - I kept pulling my hair at falco 😉.
