import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static values = { container: String };

  connect() {
    console.log("Connecting to logs for:", this.containerValue);

    App.cable.subscriptions.create(
      { channel: "DockerLogChannel", container: this.containerValue },
      {
        received: (data) => {
          const div = document.createElement("div");
          div.textContent = data.log;
          this.element.appendChild(div);
          this.element.scrollTop = this.element.scrollHeight;
        },
      }
    );
  }
}
