// Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
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