This (guide)[https://github.com/infokiller/win10-vm] on setting up virtual and latest (repository)[https://fedorapeople.org/groups/virt/virtio-win/direct-downloads/latest-virtio/] for virtio.

To install TIA in Tiny10 use this guide from (reddit)[https://www.reddit.com/r/tiny10/comments/1128tny/how_to_install_internet_explorer_on_tiny_10/]:
for people seeing this post in the future, if roblox doesn't open in tiny10 then do this:
```bash
1] open Registry Editor
2] go here: Computer\HKEY_LOCAL_MACHINE\SOFTWARE\WOW6432Node\Microsoft\Internet Explorer
3] right click > new > String Value
4] rename the newly created file to "Version" - exactly like this
5] open the "Version" file, in the "Value Data:" field put "9.11.25211.0" - exactly like thisand that's it! go play roblox! and enjoy!
```


Next step is .NET 3.5 SP1 from this (thread)[https://www.reddit.com/r/tiny10/comments/vfmivl/cant_install_net_and_directx_in_tiny10_can_anyone/]
```
For those who find this post now, you can install dotnet 3.5 (and probably other features (if you can find the featureName) through cmd prompt. You just need a windows/tiny10 iso or boot usb drive etc.



Plug in your USB drive or find your iso

open cmd/powershell as admin

run the below cmd changing the /Source to the location/drive of your iso/boot drive

dism /online /enable-feature /featurename:NetFX3 /All /Source:D:\sources\sxs /LimitAccess
dism /online /Add-Capability /CapabilityName:Browser.InternetExplorer~~~~0.0.11.0 /Source:D:\sources\sxs /LimitAccess
```
