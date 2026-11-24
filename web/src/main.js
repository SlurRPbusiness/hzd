import { mount } from "svelte";
import App from "./App.svelte";
import "./styles/tokens.css";
import "./styles/notifications.css";
import "./styles/devmode.css";

mount(App, { target: document.getElementById("app") });
