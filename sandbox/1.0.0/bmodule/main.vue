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
              :disabled="filepath.trim().length == 0"
              @click="scanFile"
            >
              {{ locale[$i18n.locale]["buttonScan"] }}
            </el-button>
          </el-input>
        </div>
        <el-table border table-layout="auto" :data="tableData">
          <el-table-column
            v-for="(col, i) in tableColumns"
            :key="i"
            :prop="col.name"
            :label="col.name"
            sortable
          />
        </el-table>
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
      query: "SELECT * FROM scan",
      results: [["Task ID", "Filename", "Status"]],
      connection: undefined,
      locale: {
        ru: {
          api: "Проверка файлов",
          buttonScan: "Проверить файл",
          connected: "— подключение к серверу установлено",
          connServerError: "Не удалось подключиться к серверу",
          connAgentError: "Не удалось подключиться к агенту",
          filePl: "Путь к файлу",
          scanRequestLoading: "Запрос был отправлен",
          unknownMessageError: "Получен неизвестный тип сообщения",
        },
        en: {
          api: "File scan",
          buttonScan: "Scan",
          connected: "— connection to the server established",
          connServerError: "Failed to connect to the server",
          connAgentError: "Failed to connect to the agent",
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
          this.requestData();
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
    computed: {
      tableData() {
        const headers = this.results[0];
        return this.results
          .slice(1)
          .map((r) => r.reduce((o, v, i) => ({ ...o, [headers[i]]: v }), {}));
      },
      tableColumns() {
        return this.results[0].map((c) => ({ name: c }));
      },
    },
    methods: {
      onData(packet) {
        const data = new TextDecoder("utf-8").decode(packet.content.data);
        const msg = JSON.parse(data);
        if (msg.type == "connection_error") {
          this.$root.NotificationsService.error(
            this.locale[this.$i18n.locale]["connAgentError"]
          );
        } else if (msg.type == "display_data") {
          this.results = msg.data;
        } else {
          this.$root.NotificationsService.error(
            this.locale[this.$i18n.locale]["unknownMessageError"]
          );
        }
      },
      requestData() {
        this.connection.sendData(
          JSON.stringify({ type: "request_data", query: this.query })
        );
      },
      scanFile() {
        this.connection.sendData(
          JSON.stringify({ type: "scan_file", path: this.filepath.trim() })
        );
        this.$root.NotificationsService.success(
          this.locale[this.$i18n.locale]["scanRequestLoading"]
        );
      },
    },
  };
</script>
