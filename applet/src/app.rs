// SPDX-License-Identifier: GPL-3.0-only

use crate::power;
use crate::power::PowerAction;
use cosmic::app::{Core, Task};
use cosmic::applet::{menu_button, padded_control};
use cosmic::cosmic_config::{Config, CosmicConfigEntry};
use cosmic::cosmic_theme::Spacing;
use cosmic::iced::window::Id;
use cosmic::iced::{Limits, Subscription};
use cosmic::iced_winit::commands::popup::{destroy_popup, get_popup};
use cosmic::widget;
use cosmic::{Application, Element};
use liblog::{IMAGES, LogoMenuConfig, MenuItemType};
use std::fs;
use std::path::Path;
use std::process::Command;

const ID: &str = "dev.cappsy.CosmicExtAppletLogoMenu";

pub struct LogoMenu {
    core: Core,
    popup: Option<Id>,
    config: LogoMenuConfig,
    is_flatpak: bool,
    osd_cmd: String,
}

#[derive(Debug, Clone)]
pub enum Message {
    TogglePopup,
    PopupClosed(Id),
    Run(String),
    Action(power::PowerAction),
    Zbus(Result<(), zbus::Error>),
    ConfigUpdate(LogoMenuConfig),
}

impl Application for LogoMenu {
    type Executor = cosmic::executor::Default;
    type Flags = ();
    type Message = Message;
    const APP_ID: &str = ID;

    fn core(&self) -> &Core {
        &self.core
    }

    fn core_mut(&mut self) -> &mut Core {
        &mut self.core
    }

    fn init(core: Core, _flags: Self::Flags) -> (Self, Task<Self::Message>) {
        // Load config
        let helper = Config::new(ID, LogoMenuConfig::VERSION).ok();
        let config: LogoMenuConfig = helper
            .as_ref()
            .map(|helper| {
                LogoMenuConfig::get_entry(helper).unwrap_or_else(|(_errors, config)| config)
            })
            .unwrap_or_default();

        // set flatpag flag
        let is_flatpak = is_flatpak();

        // get cosmic_osd command based on the distro
        let osd_cmd = match is_nixos() {
            true => String::from("/run/current-system/sw/bin/cosmic-osd"),
            false => String::from("cosmic-osd"),
        };

        let app = LogoMenu {
            core,
            popup: None,
            config,
            is_flatpak,
            osd_cmd,
        };
        (app, Task::none())
    }

    fn on_close_requested(&self, id: Id) -> Option<Message> {
        Some(Message::PopupClosed(id))
    }

    fn view(&self) -> Element<'_, Self::Message> {
        // If custom logo is active and there is a valid one set
        let logo_widget = if self.config.custom_logo_active
            && Path::new(&self.config.custom_logo_path).exists()
        {
            // Load custom logo
            cosmic::widget::icon::from_svg_bytes(fs::read(&self.config.custom_logo_path).unwrap())
                .symbolic(if self.config.custom_logo_path.contains("-symbolic.svg") {
                    true
                } else {
                    false
                })
        } else {
            // Get the current logo with appropriate fallback
            let selected_logo_name = if IMAGES.contains_key(&self.config.logo) {
                &self.config.logo
            } else {
                &LogoMenuConfig::default().logo
            };
            let logo_bytes = IMAGES[selected_logo_name];

            cosmic::widget::icon::from_svg_bytes(logo_bytes.0).symbolic(logo_bytes.1)
        };

        self.core
            .applet
            .icon_button_from_handle(logo_widget)
            .on_press(Message::TogglePopup)
            .padding(0)
            .into()
    }

    fn view_window(&self, _id: Id) -> Element<'_, Self::Message> {
        let Spacing {
            space_xxs, space_s, ..
        } = cosmic::theme::active().cosmic().spacing;

        // Get the menu from config
        let config_menuitems = &self.config.menu_items;

        let mut content_list = widget::column().padding([8, 0]).spacing(0);
        for item in &config_menuitems.items {
            match item.item_type() {
                MenuItemType::LaunchAction => {
                    content_list = content_list.push(
                        menu_button(widget::text::body(item.label().unwrap_or_default()))
                            .on_press(Message::Run(item.command().unwrap_or_default())),
                    )
                }
                MenuItemType::PowerAction => {
                    content_list = content_list.push(
                        menu_button(widget::text::body(item.label().unwrap_or_default())).on_press(
                            Message::Action(match item.command() {
                                Some(command) => match command.as_ref() {
                                    "Lock" => PowerAction::Lock,
                                    "Logout" => PowerAction::LogOut,
                                    "Suspend" => PowerAction::Suspend,
                                    "Restart" => PowerAction::Restart,
                                    "Shutdown" => PowerAction::Shutdown,
                                    _ => PowerAction::LogOut,
                                },
                                _ => PowerAction::Shutdown,
                            }),
                        ),
                    )
                }
                MenuItemType::Divider => {
                    content_list = content_list.push(
                        padded_control(widget::divider::horizontal::default())
                            .padding([space_xxs, space_s]),
                    )
                }
            };
        }

        self.core.applet.popup_container(content_list).into()
    }

    fn subscription(&self) -> Subscription<Message> {
        Subscription::batch(vec![
            self.core
                .watch_config(ID)
                .map(|res| Message::ConfigUpdate(res.config)),
        ])
    }

    fn update(&mut self, message: Self::Message) -> Task<Self::Message> {
        match message {
            Message::TogglePopup => {
                return if let Some(p) = self.popup.take() {
                    destroy_popup(p)
                } else {
                    let new_id = Id::unique();
                    self.popup.replace(new_id);
                    let mut popup_settings = self.core.applet.get_popup_settings(
                        self.core.main_window_id().unwrap(),
                        new_id,
                        None,
                        None,
                        None,
                    );
                    popup_settings.positioner.size_limits = Limits::NONE
                        .max_width(372.0)
                        .min_width(300.0)
                        .min_height(200.0)
                        .max_height(1080.0);
                    get_popup(popup_settings)
                };
            }
            Message::Action(action) => {
                let osd_arg = match action {
                    power::PowerAction::LogOut => "log-out",
                    power::PowerAction::Restart => "restart",
                    power::PowerAction::Shutdown => "shutdown",
                    _ => return action.perform(),
                };

                if self.is_flatpak {
                    if let Err(_err) = Command::new("flatpak-spawn")
                        .arg("--host")
                        .arg(&self.osd_cmd)
                        .arg(osd_arg)
                        .spawn()
                    {
                        return action.perform();
                    }
                } else if let Err(_err) = Command::new("cosmic-osd").arg(osd_arg).spawn() {
                    return action.perform();
                }

                return close_popup(self.popup);
            }
            Message::Zbus(result) => {
                if let Err(e) = result {
                    eprintln!("cosmic-ext-applet-logomenu ERROR: '{}'", e);
                }
            }
            Message::PopupClosed(id) => {
                if self.popup.as_ref() == Some(&id) {
                    self.popup = None;
                }
            }
            Message::Run(action) => {
                if self.is_flatpak
                    && action != "cosmic-ext-logomenu-settings"
                    && action != "cosmic-logomenu-settings"
                {
                    match Command::new("flatpak-spawn")
                        .args(["--host", "/bin/sh", "-c", "-l", &action])
                        .spawn()
                    {
                        Ok(_) => {}
                        Err(e) => eprintln!("Error executing command: {}", e),
                    }
                } else {
                    match Command::new("bash")
                        .arg("-c")
                        .arg(if &action == "cosmic-logomenu-settings" {
                            "cosmic-ext-logomenu-settings"
                        } else {
                            &action
                        })
                        .spawn()
                    {
                        Ok(_) => {}
                        Err(e) => eprintln!("Error executing command: {}", e),
                    };
                }

                return close_popup(self.popup);
            }
            Message::ConfigUpdate(config) => {
                self.config = config;
            }
        }
        Task::none()
    }

    fn style(&self) -> std::option::Option<cosmic::iced::theme::Style> {
        Some(cosmic::applet::style())
    }
}

fn close_popup(mut popup: Option<Id>) -> Task<Message> {
    if let Some(p) = popup.take() {
        destroy_popup(p)
    } else {
        Task::none()
    }
}

#[cfg(feature = "flatpak")]
fn is_flatpak() -> bool {
    true
}

#[cfg(not(feature = "flatpak"))]
fn is_flatpak() -> bool {
    false
}

fn is_nixos() -> bool {
    fs::exists("/run/host/etc/NIXOS").unwrap_or(false)
}
