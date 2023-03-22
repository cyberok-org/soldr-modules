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
        <div ref="boxTable" style="flex-grow: 1">
          <el-table border :max-height="maxTableHeight" :data="tableData">
            <el-table-column
              v-for="(col, i) in tableColumns"
              :key="i"
              :prop="col.name"
              :label="col.name"
              :width="col.width"
              sortable
            />
          </el-table>
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
      filename: "",
      sqlQuery: "SELECT * FROM scan",
      results: undefined,
      maxTableHeight: 585,
      timerId: undefined,
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
          AgentNotAvailableError: "Не удалось подключиться к агенту",
          CuckooCreateTaskError: "Сервер Cuckoo не доступен / вернул ошибку",
          CuckooError: "Сервер Cuckoo не доступен / вернул ошибку",
          ExecSQLError: "Ошибка выполнения SQL-запроса",
          RequestFileError: "Нe удалось получить файл",
          ScanCreateError: "Не удалось создать новую запись в базе данных",
          ScanGetError: "Ошибка чтения из базы данных",
          ScanUpdateError: "Ошибка записи в базу данных",
          SendFileError: "Не удалось получить файл",
          ServerNotAvailableError: "Не удалось подключиться к серверу",
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
          window.addEventListener("resize", this.resizeTable);
          this.timerId = window.setInterval(this.resizeTable, 100);
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
    destroyed() {
      if (this.viewMode != "agent") {
        return;
      }
      window.removeEventListener("resize", this.resizeTable);
      window.clearInterval(this.timerId);
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
        return this.results[0].map((c, i) => ({
          name: c,
          width: this.results.reduce((acc, row) => {
            const paddingPx = 40;
            const charWidthPx = 8.7;
            const cellLength = (row[i] || "null").toString().length;
            const cellWidth = cellLength * charWidthPx + paddingPx;
            return Math.max(acc, cellWidth);
          }, 0),
        }));
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
          const localized = this.locale[this.$i18n.locale][msg.error.name];
          const message = localized || `[${msg.error.name}] ${msg.error.message}`;
          this.$root.NotificationsService.error(message);
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
      resizeTable() {
        this.maxTableHeight = this.$refs.boxTable.clientHeight - 1;
      },
    },
  };
</script>
