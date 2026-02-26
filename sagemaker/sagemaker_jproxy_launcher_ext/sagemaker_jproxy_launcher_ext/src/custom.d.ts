// Copyright Jianfei Gao. All Rights Reserved.
// Originally by Giuseppe Angelo Porcelli (aws-samples/sagemaker-codeserver).
// SPDX-License-Identifier: MIT-0
declare module "*.svg" {
    const content: string;
    export default content;
}


interface IServerProcess {
    name: string;
    launcher_entry: ILauncherEntry;
    new_browser_tab: boolean;
}


interface ILauncherEntry {
    enabled: boolean;
    title: string;
    path_info: string;
}


interface IServersInfo {
    server_processes: IServerProcess[];
}