import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qinglong_app/base/http/http.dart';
import 'package:qinglong_app/base/ql_app_bar.dart';
import 'package:qinglong_app/base/single_account_page.dart';
import 'package:qinglong_app/base/theme.dart';
import 'package:qinglong_app/base/ui/tree/models/script_data.dart';
import 'package:qinglong_app/module/config/config_page.dart';
import 'package:qinglong_app/module/env/env_bean.dart';
import 'package:qinglong_app/module/others/other_page.dart';
import 'package:qinglong_app/module/others/scripts/script_upload_page.dart';
import 'package:qinglong_app/module/task/add_task_page.dart';
import 'package:qinglong_app/module/task/task_bean.dart';
import 'package:qinglong_app/utils/extension.dart';

import '../../main.dart';
import 'system_bean.dart';

/// 脚本为中心的单页首页：
/// 1. 展示所有脚本文件及其定时任务（运行时间显示 + 一键运行）
/// 2. 每个脚本可展开独立的变量组（以脚本名为分组标记，互不干扰）
/// 3. 顶部提供上传脚本（导入后可自定义运行时间）、配置、我的入口
class ScriptHomePage extends ConsumerStatefulWidget {
  const ScriptHomePage({Key? key}) : super(key: key);

  @override
  ConsumerState<ScriptHomePage> createState() => _ScriptHomePageState();
}

class _ScriptItem {
  final String title;
  final String path;
  TaskBean? task;
  List<EnvBean> envs = [];

  _ScriptItem(this.title, this.path);
}

class _ScriptHomePageState extends ConsumerState<ScriptHomePage> {
  bool loading = true;
  List<_ScriptItem> items = [];
  Set<String> expandedSet = {};
  String keyword = "";

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((timeStamp) {
      load();
    });
  }

  Future<void> load() async {
    if (items.isEmpty) {
      setState(() {
        loading = true;
      });
    }
    var api = SingleAccountPageState.ofApi(context);

    List<TaskBean> tasks = [];
    List<EnvBean> envs = [];
    List<ScriptData> scriptTree = [];

    var scriptResp = await api.scripts();
    if (scriptResp.success && scriptResp.bean != null) {
      scriptTree = scriptResp.bean!;
    }

    if (getIt<SystemBean>(instanceName: (SingleAccountPageState.of(context)?.index ?? 0).toString())
        .isUpperVersion2_13_9()) {
      var cronsResp = await api.crons2_13_09();
      if (cronsResp.success && cronsResp.bean != null) {
        tasks = cronsResp.bean?.data ?? [];
      }
    } else {
      var cronsResp = await api.crons();
      if (cronsResp.success && cronsResp.bean != null) {
        tasks = cronsResp.bean!;
      }
    }

    var envsResp = await api.envs("");
    if (envsResp.success && envsResp.bean != null) {
      envs = envsResp.bean!;
    }

    List<ScriptData> files = [];
    void flatten(List<ScriptData> list) {
      for (var node in list) {
        if (node.type == "directory") {
          flatten(node.children);
        } else {
          files.add(node);
        }
      }
    }

    flatten(scriptTree);

    List<_ScriptItem> newItems = [];
    for (var file in files) {
      if (file.title.isEmpty) continue;
      _ScriptItem item = _ScriptItem(file.title, file.parent);
      for (var task in tasks) {
        if (task.command != null && task.command!.contains(file.title)) {
          item.task = task;
          break;
        }
      }
      for (var env in envs) {
        if (env.remarks != null && env.remarks == file.title) {
          item.envs.add(env);
        }
      }
      newItems.add(item);
    }

    newItems.sort((a, b) {
      bool aHas = a.task != null;
      bool bHas = b.task != null;
      if (aHas != bHas) return aHas ? -1 : 1;
      return a.title.compareTo(b.title);
    });

    if (!mounted) return;
    setState(() {
      items = newItems;
      loading = false;
    });
  }

  List<_ScriptItem> get filteredItems {
    if (keyword.isEmpty) return items;
    return items.where((e) => e.title.toLowerCase().contains(keyword.toLowerCase())).toList();
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        return false;
      },
      child: Scaffold(
        appBar: QlAppBar(
          canBack: false,
          title: "我的脚本",
          actions: [
            IconButton(
              icon: Icon(
                Icons.upload_file,
                color: ref.watch(themeProvider).themeColor.titleColor(),
                size: 22,
              ),
              onPressed: () async {
                await Navigator.of(context).push(
                  CupertinoPageRoute(
                    builder: (context) => const ScriptUploadPage(),
                  ),
                );
                load();
              },
            ),
            IconButton(
              icon: Icon(
                Icons.settings_outlined,
                color: ref.watch(themeProvider).themeColor.titleColor(),
                size: 22,
              ),
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => const ConfigPage(),
                  ),
                );
              },
            ),
            IconButton(
              icon: Icon(
                Icons.person_outline,
                color: ref.watch(themeProvider).themeColor.titleColor(),
                size: 22,
              ),
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => const OtherPage(),
                  ),
                );
              },
            ),
          ],
        ),
        body: loading
            ? const Center(
                child: CircularProgressIndicator(),
              )
            : RefreshIndicator(
                onRefresh: () async {
                  await load();
                },
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 6),
                      child: TextField(
                        onChanged: (value) {
                          setState(() {
                            keyword = value;
                          });
                        },
                        decoration: InputDecoration(
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          hintText: "搜索脚本",
                          prefixIcon: const Icon(Icons.search, size: 20),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: filteredItems.isEmpty
                          ? ListView(
                              children: const [
                                SizedBox(height: 100),
                                Center(child: Text("暂无脚本，点击右上角上传导入")),
                              ],
                            )
                          : ListView.builder(
                              itemCount: filteredItems.length,
                              itemBuilder: (context, index) {
                                return _buildItem(context, filteredItems[index]);
                              },
                            ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildItem(BuildContext context, _ScriptItem item) {
    bool isExpanded = expandedSet.contains(item.title);
    var theme = ref.watch(themeProvider);
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      elevation: 0,
      color: theme.themeColor.bg2Color(),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(
          color: theme.themeColor.settingBordorColor(),
          width: 0.5,
        ),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () {
                      setState(() {
                        if (isExpanded) {
                          expandedSet.remove(item.title);
                        } else {
                          expandedSet.add(item.title);
                        }
                      });
                    },
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: theme.themeColor.titleColor(),
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          item.task == null
                              ? "未设置定时"
                              : "定时：${item.task!.schedule ?? ""}",
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            color: item.task == null
                                ? theme.themeColor.hintColor()
                                : theme.themeColor.descColor(),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                if (item.task != null)
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    icon: Icon(
                      Icons.play_arrow,
                      color: theme.primaryColor,
                      size: 26,
                    ),
                    tooltip: "运行",
                    onPressed: () {
                      runTask(item);
                    },
                  )
                else
                  TextButton(
                    child: Text(
                      "设置定时",
                      style: TextStyle(
                        fontSize: 12,
                        color: theme.primaryColor,
                      ),
                    ),
                    onPressed: () {
                      createTask(item);
                    },
                  ),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  icon: Icon(
                    isExpanded ? Icons.expand_less : Icons.expand_more,
                    color: theme.themeColor.descColor(),
                    size: 24,
                  ),
                  tooltip: "环境变量",
                  onPressed: () {
                    setState(() {
                      if (isExpanded) {
                        expandedSet.remove(item.title);
                      } else {
                        expandedSet.add(item.title);
                      }
                    });
                  },
                ),
              ],
            ),
          ),
          if (isExpanded) _buildEnvSection(context, item),
        ],
      ),
    );
  }

  Future<void> runTask(_ScriptItem item) async {
    EasyLoading.show(status: "提交中...");
    HttpResponse<NullResponse> response = await SingleAccountPageState.ofApi(context)
        .startTasks([item.task!.sId ?? ""]);
    EasyLoading.dismiss();
    if (response.success) {
      "已提交运行，请稍后查看日志".toast();
    } else {
      "运行失败：${response.message}".toast();
    }
  }

  Future<void> createTask(_ScriptItem item) async {
    String separator = item.path.isEmpty ? "" : "/";
    await Navigator.of(context).push(
      CupertinoPageRoute(
        builder: (context) => AddTaskPage(
          hideUploadFile: true,
          taskBean: TaskBean(
            name: item.title,
            command: "task ${item.path}$separator${item.title}",
            schedule: "",
          ),
        ),
      ),
    );
    load();
  }

  Future<void> editSchedule(_ScriptItem item) async {
    await Navigator.of(context).push(
      CupertinoPageRoute(
        builder: (context) => AddTaskPage(
          hideUploadFile: true,
          taskBean: item.task!,
        ),
      ),
    );
    load();
  }

  Widget _buildEnvSection(BuildContext context, _ScriptItem item) {
    var theme = ref.watch(themeProvider);
    return Container(
      decoration: BoxDecoration(
        color: theme.themeColor.pinedAndWhite(),
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(10)),
      ),
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Divider(
            height: 1,
            color: theme.themeColor.settingBordorColor(),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: Text(
                  "环境变量（${item.envs.length}）· 本脚本独立",
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: theme.themeColor.titleColor(),
                  ),
                ),
              ),
              GestureDetector(
                onTap: () {
                  addEnv(context, item);
                },
                child: Row(
                  children: [
                    Icon(Icons.add, size: 16, color: theme.primaryColor),
                    Text(
                      "新增",
                      style: TextStyle(
                        fontSize: 13,
                        color: theme.primaryColor,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (item.envs.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Text(
                "暂无变量，点击右上角\"新增\"添加，变量自动归属本脚本",
                style: TextStyle(
                  fontSize: 12,
                  color: theme.themeColor.hintColor(),
                ),
              ),
            )
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: item.envs.length,
              itemBuilder: (context, index) {
                EnvBean env = item.envs[index];
                bool disabled = env.status == 0 || env.status == 4;
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              env.name ?? "",
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color: disabled
                                    ? theme.themeColor.hintColor()
                                    : theme.themeColor.titleColor(),
                                decoration:
                                    disabled ? TextDecoration.lineThrough : TextDecoration.none,
                              ),
                            ),
                            Text(
                              env.value ?? "",
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 11,
                                color: theme.themeColor.descColor(),
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        icon: Icon(
                          disabled ? Icons.toggle_off_outlined : Icons.toggle_on,
                          size: 24,
                          color: disabled
                              ? theme.themeColor.hintColor()
                              : theme.primaryColor,
                        ),
                        tooltip: disabled ? "启用" : "停用",
                        onPressed: () {
                          toggleEnv(env, disabled);
                        },
                      ),
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        icon: Icon(
                          Icons.edit_outlined,
                          size: 18,
                          color: theme.themeColor.descColor(),
                        ),
                        tooltip: "编辑",
                        onPressed: () {
                          editEnv(context, item, env);
                        },
                      ),
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        icon: Icon(
                          Icons.delete_outline,
                          size: 18,
                          color: const Color(0xffFB5858),
                        ),
                        tooltip: "删除",
                        onPressed: () {
                          delEnv(context, env, item);
                        },
                      ),
                    ],
                  ),
                );
              },
            ),
          if (item.task != null)
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                child: Text(
                  "修改定时",
                  style: TextStyle(
                    fontSize: 12,
                    color: theme.primaryColor,
                  ),
                ),
                onPressed: () {
                  editSchedule(item);
                },
              ),
            ),
        ],
      ),
    );
  }

  Future<void> toggleEnv(EnvBean env, bool currentlyDisabled) async {
    EasyLoading.show(status: "提交中...");
    HttpResponse<NullResponse> response = currentlyDisabled
        ? await SingleAccountPageState.ofApi(context).enableEnv([env.sId ?? ""])
        : await SingleAccountPageState.ofApi(context).disableEnv([env.sId ?? ""]);
    EasyLoading.dismiss();
    if (response.success) {
      currentlyDisabled ? "已启用".toast() : "已停用".toast();
      load();
    } else {
      "操作失败：${response.message}".toast();
    }
  }

  void addEnv(BuildContext context, _ScriptItem item) {
    TextEditingController nameController = TextEditingController();
    TextEditingController valueController = TextEditingController();
    showCupertinoDialog(
      context: context,
      useRootNavigator: false,
      builder: (context1) => CupertinoAlertDialog(
        title: const Text("新增环境变量"),
        content: Padding(
          padding: const EdgeInsets.only(top: 10),
          child: Column(
            children: [
              CupertinoTextField(
                controller: nameController,
                placeholder: "变量名",
              ),
              const SizedBox(height: 8),
              CupertinoTextField(
                controller: valueController,
                placeholder: "变量值",
              ),
              const SizedBox(height: 8),
              Text(
                "归属脚本：${item.title}",
                style: const TextStyle(fontSize: 12, color: Color(0xff999999)),
              ),
            ],
          ),
        ),
        actions: [
          CupertinoDialogAction(
            child: const Text("取消"),
            onPressed: () {
              Navigator.of(context1).pop();
            },
          ),
          CupertinoDialogAction(
            child: const Text("确定"),
            onPressed: () async {
              if (nameController.text.isEmpty) {
                "请输入变量名".toast();
                return;
              }
              Navigator.of(context1).pop();
              EasyLoading.show(status: "提交中...");
              HttpResponse<NullResponse> response =
                  await SingleAccountPageState.ofApi(context).addEnv(
                nameController.text.trim(),
                valueController.text,
                item.title,
              );
              EasyLoading.dismiss();
              if (response.success) {
                "添加成功".toast();
                load();
              } else {
                "添加失败：${response.message}".toast();
              }
            },
          ),
        ],
      ),
    );
  }

  void editEnv(BuildContext context, _ScriptItem item, EnvBean env) {
    TextEditingController nameController = TextEditingController(text: env.name ?? "");
    TextEditingController valueController = TextEditingController(text: env.value ?? "");
    showCupertinoDialog(
      context: context,
      useRootNavigator: false,
      builder: (context1) => CupertinoAlertDialog(
        title: const Text("编辑环境变量"),
        content: Padding(
          padding: const EdgeInsets.only(top: 10),
          child: Column(
            children: [
              CupertinoTextField(
                controller: nameController,
                placeholder: "变量名",
              ),
              const SizedBox(height: 8),
              CupertinoTextField(
                controller: valueController,
                placeholder: "变量值",
              ),
            ],
          ),
        ),
        actions: [
          CupertinoDialogAction(
            child: const Text("取消"),
            onPressed: () {
              Navigator.of(context1).pop();
            },
          ),
          CupertinoDialogAction(
            child: const Text("确定"),
            onPressed: () async {
              if (nameController.text.isEmpty) {
                "请输入变量名".toast();
                return;
              }
              Navigator.of(context1).pop();
              EasyLoading.show(status: "提交中...");
              HttpResponse<NullResponse> response =
                  await SingleAccountPageState.ofApi(context).addEnv(
                nameController.text.trim(),
                valueController.text,
                item.title,
                nId: env.nId,
              );
              EasyLoading.dismiss();
              if (response.success) {
                "修改成功".toast();
                load();
              } else {
                "修改失败：${response.message}".toast();
              }
            },
          ),
        ],
      ),
    );
  }

  Future<void> delEnv(BuildContext context, EnvBean env, _ScriptItem item) async {
    showCupertinoDialog(
      context: context,
      useRootNavigator: false,
      builder: (context1) => CupertinoAlertDialog(
        title: const Text("提示"),
        content: Text("确定删除变量 ${env.name ?? ""} 吗？"),
        actions: [
          CupertinoDialogAction(
            child: const Text("取消"),
            onPressed: () {
              Navigator.of(context1).pop();
            },
          ),
          CupertinoDialogAction(
            child: const Text(
              "确定",
              style: TextStyle(color: Color(0xffFB5858)),
            ),
            onPressed: () async {
              Navigator.of(context1).pop();
              EasyLoading.show(status: "提交中...");
              HttpResponse<NullResponse> response =
                  await SingleAccountPageState.ofApi(context).delEnv(env.sId ?? env.nId);
              EasyLoading.dismiss();
              if (response.success) {
                "删除成功".toast();
                load();
              } else {
                "删除失败：${response.message}".toast();
              }
            },
          ),
        ],
      ),
    );
  }
}
