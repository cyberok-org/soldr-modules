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
              @click="submitReqToExecAction"
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
          filePathError: "Путь к файлу задан некорректно",
          filePl: "Путь к файлу",
        },
        en: {
          api: "File scan",
          buttonExecAction: "Scan",
          connected: "— connection to the server established",
          connServerError: "Failed to connect to the server",
          filePathError: "Invalid file path",
          filePl: "File path",
        },
      },
    }),
    created() {
      if (this.viewMode === "agent") {
        this.protoAPI.connect().then(
          (connection) => {
            const date = new Date().toLocaleTimeString();
            this.connection = connection;
            this.$root.NotificationsService.success(
              `${date} ${this.locale[this.$i18n.locale]["connected"]}`
            );
          },
          (_error) => {
            this.lastSqlError =
              this.locale[this.$i18n.locale]["connServerError"];
            this.$root.NotificationsService.error(this.lastSqlError);
          }
        );
      }
    },
    mounted() {
      this.leftTab = this.viewMode === "agent" ? "api" : undefined;
    },
    methods: {
      submitReqToExecAction() {
        this.lastExecError = "";
        let filepath = this.filepath.trim();
        if (filepath === "" || filepath.length > 256) {
          this.lastExecError = this.locale[this.$i18n.locale]["filePathError"];
          this.$root.NotificationsService.error(this.lastExecError);
        } else {
          this.lastExecError = "not implemented yet";
          this.$root.NotificationsService.error(this.lastExecError);
        }
      },
    },
  };
</script>
