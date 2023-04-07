<template>
  <div>
    <el-tabs tab-position="left" v-model="leftTab" />
  </div>
</template>

<script>
const name = "empty";

module.exports = {
  name,
  props: ["protoAPI", "hash", "module", "api", "components", "viewMode"],
  data: () => ({
    leftTab: undefined,
  }),
};
</script>
