# Kevin (Jarvis++) _aka Jarvis 2.0 aka UIC 2.0_  

This repository is for educational purposes only, any liability to the project owner is dismissed, kick rocks Niantic!  

Works with [DeviceConfigManager](https://github.com/versx/DeviceConfigManager)  

Build scripts are hardcoded, change paths to suite needs. No support is provided or given.  

**Important:** You will still need to provide a MITM static library (or dynamic...) that supports dynamic library injection for this to work, this is not a full deployment solution.  

## Build  
Copy MITM app to `app.zip` within root folder path.  
```
./build/build.sh
```

## Delployment  
Copy MITM app to `app.zip` within root folder path.  
Requires Deployer-Redux commit: `74f35a42aa965fbaecc7d9f83c6167e1c4c71191` or higher with local deploy support)  
```
./build/deploy.sh (deploys to all connected devices)  
```

## Credits  
- COVID-19
- [UIC](https://github.com/RealDeviceMap/RealDeviceMap-UIControl)  
- [Lorgnette](https://gitlab.com/mzsmakr/Lorgnette)  
- [Jarvis](https://gitlab.com/dergel/jarvis)  
