// Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
// SPDX-License-Identifier: MIT-0
import { JupyterFrontEnd, JupyterFrontEndPlugin, ILayoutRestorer } from "@jupyterlab/application";
import { ILauncher } from "@jupyterlab/launcher";
import { PageConfig } from "@jupyterlab/coreutils";
import { LabIcon } from "@jupyterlab/ui-components";
import { IFrame, MainAreaWidget, WidgetTracker } from "@jupyterlab/apputils";

import CODESERVER_ICON from "../style/icons/codeserver.svg";


export const codeserverIcon = new LabIcon({
    name: "codeserver:icon",
    svgstr: CODESERVER_ICON,
});


/**
 * Create a new IFrame widget for a proxied server.
 *
 * Args
 * ----
 * - id
 *     Unique widget identifier.
 * - url
 *     URL to load inside the IFrame.
 * - text
 *     Label shown on the widget tab.
 *
 * Returns
 * -------
 * - widget
 *     A `MainAreaWidget` wrapping the IFrame.
 */
function newServerProxyWidget(id: string, url: string, text: string): MainAreaWidget<IFrame> {
    const content = new IFrame({
        sandbox: [
            "allow-same-origin",
            "allow-scripts",
            "allow-popups",
            "allow-forms",
            "allow-downloads",
            "allow-modals",
        ],
    });
    content.title.label = text;
    content.title.closable = true;
    content.url = url;
    content.addClass("jp-ServerProxy");
    content.id = id;
    const widget = new MainAreaWidget({ content });
    widget.addClass("jp-ServerProxy");
    return widget;
}


/**
 * Fetch metadata about registered server-proxy servers.
 *
 * Args
 * ----
 * (No-Args)
 *
 * Returns
 * -------
 * - data
 *     Server process metadata, or `null` if the fetch fails.
 */
async function fetchServersInfo(): Promise<IServersInfo | null> {
    const response = await fetch(PageConfig.getBaseUrl() + "server-proxy/servers-info");
    if (!response.ok) {
        console.log(
            "Could not fetch metadata about registered servers."
            + " Make sure jupyter-server-proxy is installed.",
        );
        console.log(response);
        return null;
    }
    return response.json();
}


/**
 * Register the open-proxy command and configure widget tracking with restore.
 *
 * Args
 * ----
 * - app
 *     The JupyterLab application instance.
 * - restorer
 *     Layout restorer for persisting widget state across reloads.
 * - namespace
 *     Namespace prefix for the widget tracker and command.
 * - tracker
 *     Widget tracker for IFrame proxy widgets.
 *
 * Returns
 * -------
 * - command
 *     The registered command identifier string.
 */
function registerProxyCommand(
    app: JupyterFrontEnd,
    restorer: ILayoutRestorer,
    namespace: string,
    tracker: WidgetTracker<MainAreaWidget<IFrame>>,
): string {
    const { commands, shell } = app;
    const command = namespace + ":" + "open";

    if (restorer) {
        void restorer.restore(tracker, {
            command: command,
            args: (widget: MainAreaWidget<IFrame>) => ({
                url: widget.content.url,
                title: widget.content.title.label,
                newBrowserTab: false,
                id: widget.content.id,
            }),
            name: (widget: MainAreaWidget<IFrame>) => widget.content.id,
        });
    }

    commands.addCommand(command, {
        label: (args: Record<string, unknown>) => args["title"] as string,
        icon: () => codeserverIcon,
        execute: (args: Record<string, unknown>) => {
            const id = args["id"] as string;
            const title = args["title"] as string;
            const url = args["url"] as string;
            const newBrowserTab = args["newBrowserTab"] as boolean;

            if (newBrowserTab) {
                window.open(url, "_blank");
                return;
            }
            let widget = tracker.find((w: MainAreaWidget<IFrame>) => w.content.id === id);
            if (!widget) {
                widget = newServerProxyWidget(id, url, title);
            }
            if (!tracker.has(widget)) {
                void tracker.add(widget);
            }
            if (!widget.isAttached) {
                shell.add(widget, "main");
                return widget;
            } else {
                shell.activateById(widget.id);
            }
        },
    });

    return command;
}


/**
 * Add launcher items for each enabled server process.
 *
 * Args
 * ----
 * - launcher
 *     The JupyterLab launcher to add items to.
 * - data
 *     Server process metadata from `jupyter-server-proxy`.
 * - namespace
 *     Namespace prefix used for widget identifiers.
 * - command
 *     The registered command to invoke when a launcher item is clicked.
 *
 * Returns
 * -------
 * (No-Returns)
 */
function addLauncherItems(
    launcher: ILauncher,
    data: IServersInfo,
    namespace: string,
    command: string,
): void {
    for (const server_process of data.server_processes) {
        if (!server_process.launcher_entry.enabled) {
            continue;
        }

        const url = PageConfig.getBaseUrl() + server_process.launcher_entry.path_info;
        const title = server_process.launcher_entry.title;
        const newBrowserTab = server_process.new_browser_tab;
        const id = namespace + ":" + server_process.name;

        const launcher_item: ILauncher.IItemOptions = {
            command: command,
            args: {
                url: url,
                title: title,
                newBrowserTab: newBrowserTab,
                id: id,
            },
            category: "Other",
        };

        launcher.add(launcher_item);
    }
}


/**
 * Activate the server-proxy launcher extension.
 *
 * Fetches registered server-proxy endpoints, registers a command to open
 * them in IFrame widgets, and adds launcher cards for each enabled server.
 *
 * Args
 * ----
 * - app
 *     The JupyterLab application instance.
 * - launcher
 *     The JupyterLab launcher service.
 * - restorer
 *     Layout restorer for persisting widget state across reloads.
 *
 * Returns
 * -------
 * (No-Returns)
 */
async function activate(
    app: JupyterFrontEnd,
    launcher: ILauncher,
    restorer: ILayoutRestorer,
): Promise<void> {
    const data = await fetchServersInfo();
    if (!data) {
        return;
    }

    const namespace = "sm-server-proxy";
    const tracker = new WidgetTracker<MainAreaWidget<IFrame>>({ namespace });
    const command = registerProxyCommand(app, restorer, namespace, tracker);
    addLauncherItems(launcher, data, namespace, command);
}


const extension: JupyterFrontEndPlugin<void> = {
    id: "sagemaker-jproxy-launcher-ext",
    autoStart: true,
    requires: [ILauncher, ILayoutRestorer],
    activate: activate,
};


export default extension;