// Entry point for the build script in your package.json
import "@hotwired/turbo";
import { Application } from "@hotwired/stimulus";
import { createConsumer } from "@rails/actioncable";

import DockerLogController from "./controllers/docker_log_controller";

// Stimulus
window.Stimulus = Application.start();
Stimulus.register("docker-log", DockerLogController);

// Action Cable Consumer (optional global)
window.App = {};
App.cable = createConsumer();
