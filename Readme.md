
# Create StorJ Identities in bulk
Are you trying to create bulk StorJ identities for a project you're working on? I had the same issue, and have automated the task - so fear not, you've come to the right place: [StorjBulkIdentityCreator](https://github.com/Jikkelsen/StorjBulkIdentityCreator)

## Quick Start

* Download the files
* Populate the `NodeInfo.csv` file
* Run `StorjBulkIdentityCreator.ps1`
* Copy the files to their final destination
* Start your node

# Video walkthrough
I've made a short video showing how the script works. That can be seen below ↓

___
# Step By step guide

1. Download the files from this github repository. Either use git, or download the files as a `.zip` archive directly [from here](https://github.com/Jikkelsen/StorjBulkIdentityCreator/archive/refs/heads/main.zip)
2. Populate the `NodeInfo.csv` file.
I've included sample text, that you **must replace** with your own information. Below is the information you should replace in the file:
* **NodeName** - This is your own choice, call your nodes whatever you want, as long as there are no duplicates
* **Token** - Copy/Paste the token you get from the [Signup page](https://www.storj.io/host-a-node
* **Dashboard Port** - The port of the dashboard, that each token will have
* **External Port** - The external port of the node, that it will communicate with the world on
* **IP** - The external IP of your node
* **Wallet** - Your StorJ wallet address.

3. Open `PowerShell`
4. Navigate to the directory of your downloaded files
5. Run the script by issuing `.\StorjBulkIdentityCreator.ps1`
If you don't supply any options, the script will default to look for the `nodeinfo.csv`, `TEMPLATE_docker-compose.yaml` and `TEMPLATE_setup.commands` file in the same directory as the main script. If you've not moved any files around, this is where they will be.
The script will dump your newly created identities in `$HOME\documents\StorjIdentitycreator`. This is to ensure that all identities are in the same place for future reference. You can override this behavior by issuing the `-WorkingDirectory` flag with a new directory

6. The script will now create your identities one by one.
I have not implemented any multithreading, but am will work on that in the future :)
7. `Copy` or `move` your identities to their target locations



# Known issues

"I get an error akin to: `File cannot be loaded because the execution of scripts is disabled on this system. Please see "get-help about_signing" for more details`"
* Open `PowerShell` as Administrator
* Paste in the command below:
```Powershell
Set-ExecutionPolicy Unrestricted -confirm:$false
```
* Rerun the the script
