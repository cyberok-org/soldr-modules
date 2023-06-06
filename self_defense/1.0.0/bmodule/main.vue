<template>
  <el-result icon="info" :title="strings.managementIsUnsupported" />
</template>

<script>
const name = "cyberok_self_defense";

module.exports = {
  name,
  props: ["protoAPI", "hash", "module", "api", "components", "viewMode"],
  data: () => ({}),
  computed: {
    strings() {
      return {
        ru: {
          managementIsUnsupported: "Управление не поддерживается",
        },
        en: {
          managementIsUnsupported: "Management is not supported",
        },
      }[this.$i18n.locale];
    },
  },
};
</script>
