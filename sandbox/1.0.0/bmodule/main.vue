<template>
  <div>
    <el-tabs tab-position="left" v-model="leftTab">
      <el-tab-pane
        name="api"
        :label="locale[$i18n.locale]['api']"
        class="layout-fill_vertical uk-flex uk-flex-column uk-overflow-hidden"
        v-if="viewMode === 'agent'"
      >
        <div class="uk-margin limit-length">
          <el-input
            :placeholder="locale[$i18n.locale]['filePl']"
            v-model="filepath"
          >
            <el-button
              slot="append"
              icon="el-icon-s-promotion"
              class="uk-flex-none"
              @click="scanFile"
              >{{ locale[$i18n.locale]["buttonExecAction"] }}
            </el-button>
          </el-input>
          <div id="error" v-if="lastExecError" class="invalid-feedback">
            {{ lastExecError }}
          </div>
        </div>
      </el-tab-pane>
    </el-tabs>
  </div>
</template>

<script>
  const name = "cyberok_sandbox";

  module.exports = {
    name,
    props: ["protoAPI", "hash", "module", "api", "components", "viewMode"],
    data: () => ({
      leftTab: undefined,
      filepath: "",
      connection: undefined,
      lastExecError: "",
      locale: {
        ru: {
          api: "Проверка файлов",
          buttonExecAction: "Проверить файл",
          connected: "— подключение к серверу установлено",
          connServerError: "Не удалось подключиться к серверу",
          connAgentError: "Не удалось подключиться к агенту",
          filePathError: "Путь к файлу задан некорректно",
          filePl: "Путь к файлу",
          scanRequestLoading: "Запрос был отправлен",
          unknownMessageError: "Получен неизвестный тип сообщения",
        },
        en: {
          api: "File scan",
          buttonExecAction: "Scan",
          connected: "— connection to the server established",
          connServerError: "Failed to connect to the server",
          connAgentError: "Failed to connect to the agent",
          filePathError: "Invalid file path",
          filePl: "File path",
          scanRequestLoading: "Request has been sent",
          unknownMessageError: "Received unknown message type",
        },
      },
    }),
    created() {
      if (this.viewMode != "agent") {
        return;
      }
      this.protoAPI.connect().then(
        (connection) => {
          const date = new Date().toLocaleTimeString();
          this.connection = connection;
          this.connection.subscribe(this.onData, "data");
          this.$root.NotificationsService.success(
            `${date} ${this.locale[this.$i18n.locale]["connected"]}`
          );
        },
        (_error) => {
          this.$root.NotificationsService.error(
            this.locale[this.$i18n.locale]["connServerError"]
          );
        }
      );
    },
    mounted() {
      this.leftTab = this.viewMode === "agent" ? "api" : undefined;
    },
    methods: {
      onData(packet) {
        let data = new TextDecoder("utf-8").decode(packet.content.data);
        let msg = JSON.parse(data);
        if ((msg.type = "connection_error")) {
          this.$root.NotificationsService.error(
            this.locale[this.$i18n.locale]["connAgentError"]
          );
        } else {
          this.$root.NotificationsService.error(
            this.locale[this.$i18n.locale]["unknownMessageError"]
          );
        }
      },
      scanFile() {
        let filepath = this.filepath.trim();
        if (filepath === "") {
          this.lastExecError = this.locale[this.$i18n.locale]["filePathError"];
          this.$root.NotificationsService.error(this.lastExecError);
          return;
        }
        this.connection.sendData(
          JSON.stringify({ type: "scan_file", path: filepath })
        );
        this.$root.NotificationsService.success(
          this.locale[this.$i18n.locale]["scanRequestLoading"]
        );
        this.lastExecError = "";
      },
    },
  };
</script>
