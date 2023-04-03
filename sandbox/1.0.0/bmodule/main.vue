<template>
  <div v-if="viewMode === 'agent'">
    <el-row class="uk-margin" gutter="10">
      <el-col span="16">
        <el-input :placeholder="locale[$i18n.locale]['filePlaceholder']" v-model="filename">
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
      </el-col>
      <el-col span="8">
        <el-input placeholder="scan_id" v-model="scanID" type="number">
          <el-button
            slot="append"
            class="uk-flex-none"
            :disabled="scanID.trim().length == 0 || !connection"
            @click="requestReport"
          >
            {{ locale[$i18n.locale]["buttonDownloadReport"] }}
          </el-button>
        </el-input>
      </el-col>
    </el-row>
    <div>
      <ncform :form-schema="cuckooOptionsSchema" form-name="options" v-model="cuckooOptionsSchema.value" />
    </div>
    <div>
      <el-input
        type="textarea"
        :autosize="{ minRows: 1, maxRows: 8 }"
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
    <div ref="boxTable" class="uk-margin">
      <el-table border :data="tableData">
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
  </div>
  <el-result v-else icon="info" title="locale[$i18n.locale].groupManagementUnsupported" />
</template>

<script>
  const name = "cyberok_sandbox";

  module.exports = {
    name,
    props: ["protoAPI", "hash", "module", "api", "components", "viewMode"],
    data: () => ({
      filename: "",
      sqlQuery:
        "SELECT scan_id, updated_at, filename, status, report_url, error FROM scan ORDER BY updated_at DESC LIMIT 10;",
      results: undefined,
      scanID: "",
      connection: undefined,
      locale: {
        ru: {
          api: "Проверка файлов",
          buttonExecSQL: "Выполнить запрос",
          buttonScan: "Проверить файл",
          buttonDownloadReport: "Скачать отчет",
          connected: "— подключение к серверу установлено",
          connServerError: "Не удалось подключиться к серверу",
          connAgentError: "Не удалось подключиться к агенту",
          filePlaceholder: "Путь к файлу",
          queryPlaceholder: "SQL-запрос для выборки",
          scanRequestLoading: "Запрос был отправлен",
          groupManagementUnsupported: "Групповое управление не поддерживается",
          unknownMessageError: "Получен неизвестный тип сообщения",
          AgentNotAvailableError: "Не удалось подключиться к агенту",
          CuckooCreateTaskError: "Сервер Cuckoo не доступен / вернул ошибку",
          CuckooError: "Сервер Cuckoo не доступен / вернул ошибку",
          ExecSQLError: "Ошибка выполнения SQL-запроса",
          RequestFileError: "Нe удалось получить файл",
          ScanCreateError: "Не удалось создать новую запись в базе данных",
          ScanGetError: "Ошибка чтения из базы данных",
          ScanNoReportError: "Запрошенная задача не содержит отчет сканирования",
          ScanUpdateError: "Ошибка записи в базу данных",
          SendFileError: "Не удалось получить файл",
          ServerNotAvailableError: "Не удалось подключиться к серверу",
        },
        en: {
          api: "File scan",
          buttonExecSQL: "Execute query",
          buttonScan: "Scan",
          buttonDownloadReport: "Download report",
          connected: "— connection to the server established",
          connServerError: "Failed to connect to the server",
          connAgentError: "Failed to connect to the agent",
          filePlaceholder: "File path",
          queryPlaceholder: "SQL query for selection",
          scanRequestLoading: "Request has been sent",
          groupManagementUnsupported: "Group management is not supported",
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
          this.$root.NotificationsService.success(`${date} ${this.locale[this.$i18n.locale]["connected"]}`);
        },
        (_error) => {
          this.$root.NotificationsService.error(this.locale[this.$i18n.locale]["connServerError"]);
        }
      );
    },
    mounted() {
      // https://github.com/vxcontrol/soldr/issues/105
      let appViews = document.getElementsByTagName("soldr-module-interactive-part");
      for (appView of appViews) {
        appView.classList.remove("layout-fill", "scrollable-y", "layout-padding-l");
      }
    },
    computed: {
      tableData() {
        if (!this.results || this.results.length < 2) return [];
        const headers = this.results[0];
        return this.results.slice(1).map((r) => r.reduce((o, v, i) => ({ ...o, [headers[i]]: v }), {}));
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
      cuckooOptionsSchema() {
        const appendWidgetFromConfig = (schema, widgetName) => {
          let widget = structuredClone(this.module.config_schema.properties[widgetName]);
          widget.ui.label = this.configLabel(widgetName);
          widget.ui.description = this.configLabel(widgetName, "description");
          schema.properties[widgetName] = widget;
          schema.value[widgetName] = this.module.current_config[widgetName];
        };

        let schema = { type: "object", properties: {}, value: {} };
        appendWidgetFromConfig(schema, "b1_cuckoo_package");
        appendWidgetFromConfig(schema, "b2_cuckoo_package_options");
        appendWidgetFromConfig(schema, "b3_cuckoo_priority");
        appendWidgetFromConfig(schema, "c1_cuckoo_platform");
        appendWidgetFromConfig(schema, "c2_cuckoo_machine");
        appendWidgetFromConfig(schema, "c3_cuckoo_timeout");
        return schema;
      },
    },
    methods: {
      onData(packet) {
        const data = new TextDecoder("utf-8").decode(packet.content.data);
        const msg = JSON.parse(data);
        if (msg.type == "show_sql_rows") {
          this.results = msg.data;
        } else if (msg.type == "receive_report") {
          const blob = new Blob([msg.report], { type: "application/json" });
          const a = document.createElement("a");
          a.href = window.URL.createObjectURL(blob);
          a.download = "report.json";
          a.click();
        } else if (msg.type == "error") {
          const localized = this.locale[this.$i18n.locale][msg.error.name];
          const message = localized || `[${msg.error.name}] ${msg.error.message}`;
          this.$root.NotificationsService.error(message);
        } else {
          this.$root.NotificationsService.error(this.locale[this.$i18n.locale]["unknownMessageError"]);
        }
        return true;
      },
      execSQL() {
        this.connection.sendData(JSON.stringify({ type: "exec_sql", query: this.sqlQuery }));
      },
      scanFile() {
        this.connection.sendData(
          JSON.stringify({
            type: "scan_file",
            filename: this.filename.trim(),
            cuckoo_options: {
              package: this.cuckooOptionsSchema.value.b1_cuckoo_package,
              options: this.cuckooOptionsSchema.value.b2_cuckoo_package_options,
              priority: this.cuckooOptionsSchema.value.b3_cuckoo_priority,
              platform: this.cuckooOptionsSchema.value.c1_cuckoo_platform,
              machine: this.cuckooOptionsSchema.value.c2_cuckoo_machine,
              timeout: this.cuckooOptionsSchema.value.c3_cuckoo_timeout,
            },
          })
        );
        this.$root.NotificationsService.success(this.locale[this.$i18n.locale]["scanRequestLoading"]);
      },
      requestReport() {
        this.connection.sendData(JSON.stringify({ type: "request_report", scan_id: this.scanID }));
      },
      configLabel(textID, key = "title") {
        return this.module.locale.config[textID][this.$i18n.locale][key];
      },
    },
  };
</script>
