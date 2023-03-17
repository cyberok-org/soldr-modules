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
            :placeholder="locale[$i18n.locale]['filePlaceholder']"
            v-model="filename"
          >
            <el-button
              slot="append"
              icon="el-icon-s-promotion"
              class="uk-flex-none"
              :disabled="filename.trim().length == 0 || !connection"
              @click="scanFile"
            >
              {{ locale[$i18n.locale]["buttonScan"] }}
            </el-button>
          </el-input>
        </div>
        <div>
          <el-input
            type="textarea"
            :autosize="{ minRows: 3, maxRows: 8 }"
            :placeholder="locale[$i18n.locale]['queryPlaceholder']"
            v-model="sqlQuery"
            @keyup.ctrl.enter.native="execSQL"
          />
        </div>
        <p class="uk-margin buttons">
          <el-button type="primary" @click="execSQL" :disabled="!connection">
            {{ locale[$i18n.locale]["buttonExecSQL"] }}
          </el-button>
        </p>
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
      filename: "",
      sqlQuery: "SELECT * FROM scan",
      results: undefined,
      connection: undefined,
      locale: {
        ru: {
          api: "Проверка файлов",
          buttonExecSQL: "Выполнить запрос",
          buttonScan: "Проверить файл",
          connected: "— подключение к серверу установлено",
          connServerError: "Не удалось подключиться к серверу",
          connAgentError: "Не удалось подключиться к агенту",
          filePlaceholder: "Путь к файлу",
          queryPlaceholder: "SQL-запрос для выборки",
          scanRequestLoading: "Запрос был отправлен",
          unknownMessageError: "Получен неизвестный тип сообщения",
        },
        en: {
          api: "File scan",
          buttonExecSQL: "Execute query",
          buttonScan: "Scan",
          connected: "— connection to the server established",
          connServerError: "Failed to connect to the server",
          connAgentError: "Failed to connect to the agent",
          filePlaceholder: "File path",
          queryPlaceholder: "SQL query for selection",
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
          this.execSQL();
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
        if (!this.results || this.results.length < 2) return [];
        const headers = this.results[0];
        return this.results
          .slice(1)
          .map((r) => r.reduce((o, v, i) => ({ ...o, [headers[i]]: v }), {}));
      },
      tableColumns() {
        if (!this.results || this.results.length < 1) return [];
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
        } else if (msg.type == "show_sql_rows") {
          this.results = msg.data;
        } else if (msg.type == "error") {
          const text = "[" + msg.name + "] " + msg.message;
          this.$root.NotificationsService.error(text);
        } else {
          this.$root.NotificationsService.error(
            this.locale[this.$i18n.locale]["unknownMessageError"]
          );
        }
        return true;
      },
      execSQL() {
        this.connection.sendData(
          JSON.stringify({ type: "exec_sql", query: this.sqlQuery })
        );
      },
      scanFile() {
        this.connection.sendData(
          JSON.stringify({ type: "scan_file", filename: this.filename.trim() })
        );
        this.$root.NotificationsService.success(
          this.locale[this.$i18n.locale]["scanRequestLoading"]
        );
      },
    },
  };
</script>
