use stylist::yew::styled_component;
use stylist::{css, global_style};
use yew::prelude::*;
use simuverse::*;

const LAUNCHER_TITLE:&str = "simuverse";

fn set_window_title(title: &str) {
    web_sys::window()
        .map(|w| w.document())
        .flatten()
        .expect("Unable to get DOM")
        .set_title(title);
}

fn set_global_css() {
    global_style! {
        r#"
        html {
            min-height: 100%;
            position: relative;
        }
        body {
            height: 100%;
            padding: 0;
            margin: 0;
        }
        "#
    }
    .expect("Unable to mount global style");
}

#[styled_component(Root)]
fn view() -> Html {
    set_window_title(LAUNCHER_TITLE);
    set_global_css();

    let css = css!(
        r#"
        position: absolute;
        overflow: hidden;
        width: 100%;
        height: 100%;
        "#
    );

    html! {
        <div class={ css }>
            <canvas id="wasm"></canvas>
        </div>
    }
}

fn main() {
    // Mount the DOM
    yew::start_app::<Root>();
    // Start the Simuverse App
    SimuverseApp::run();
}
