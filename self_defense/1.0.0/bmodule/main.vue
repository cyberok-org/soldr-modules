<template>
  <el-result icon="info" :title="locale.managementIsUnsupported" />
</template>

<script>
const name = "cyberok_self_defense";

module.exports = {
  name,
  props: ["protoAPI", "hash", "module", "api", "components", "viewMode"],
  data: () => ({}),
  computed: {
    locale() {
      const strings = {
        ru: {
          managementIsUnsupported: "Управление не поддерживается",
        },
        en: {
          managementIsUnsupported: "Management is not supported",
        },
      };
      return strings[this.$i18n.locale];
    },
  },
};
</script>
