import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qinglong_app/base/http/http.dart';
import 'package:qinglong_app/base/ql_app_bar.dart';
import 'package:qinglong_app/base/routes.dart';
import 'package:qinglong_app/base/single_account_page.dart';
import 'package:qinglong_app/base/theme.dart';
import 'package:qinglong_app/base/ui/lazy_load_state.dart';
import 'package:qinglong_app/base/ui/loading_widget.dart';
import 'package:qinglong_app/base/ui/search_cell.dart';
import 'package:qinglong_app/base/ui/tree/models/script_data.dart';
import 'package:qinglong_app/module/others/scripts/folder_add_page.dart';
import 'package:qinglong_app/module/others/scripts/script_env_page.dart';
import 'package:qinglong_app/module/others/scripts/script_upload_page.dart';
import 'package:qinglong_app/module/task/add_task_page.dart';
import 'package:qinglong_app/module/task/task_bean.dart';
import 'package:qinglong_app/utils/extension.dart';

import '../../../base/cupertino_sheet.dart';
import '../../../base/ui/tree/tree_view.dart';
import '../../../base/ui/tree/tree_view_controller.dart';
import '../../../main.dart';
import '../../home/system_bean.dart';

class ScriptPage extends ConsumerStatefulWidget {
  const ScriptPage({Key? key}) : super(key: key);

  @override
  _ScriptPageState createState() => _ScriptPageState();
}

class _ScriptPageState extends ConsumerState<ScriptPage> with LazyLoadState<ScriptPage> {
  List<ScriptData> list = [];

  List<TaskBean> tasks = [];

  String? path;

  ScrollController controller = ScrollController();
  TextEditingController searchText = TextEditingController();

  bool buttonshow = false;

  void scrollToTop() {
    controller.animateTo(0, duration: const Duration(milliseconds: 200), curve: Curves.linear);
  }

  @override
  void initState() {
    super.initState();
    controller.addListener(floatingButtonVisibility);
    searchText.addListener(() {
      setState(() {});
    });
  }

  void floatingButtonVisibility() {
    double y = controller.offset;
    if (y > 500) {
      if (buttonshow == true) return;
      setState(() {
        buttonshow = true;
      });
    } else {
      if (buttonshow == false) return;
      setState(() {
        buttonshow = false;
      });
    }
  }

  late TreeViewController _treeViewController;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onPanDown: (_) {
        FocusScope.of(context).requestFocus(FocusNode());
      },
      child: Scaffold(
        floatingActionButton: Visibility(
          visible: buttonshow,
          child: FloatingActionButton(
            mini: true,
            onPressed: () {
              scrollToTop();
            },
            elevation: 2,
            child: const Icon(CupertinoIcons.up_arrow),
          ),
        ),
        appBar: QlAppBar(
          canBack: true,
          backCall: () {
            Navigator.of(context).pop();
          },
          title: "脚本管理",
          actions: [
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {
                showMoreOperate(
                  context,
                  [
                    CupertinoSheer(
                      title: "新增文件",
                      onTap: () {
                        addScript();
                      },
                    ),
                    addDivider(),
                    CupertinoSheer(
                      title: "新增文件夹",
                      onTap: () {
                        SystemBean? systemBean;
                        try {
                          systemBean = getIt<SystemBean>(instanceName: (SingleAccountPageState.of(context)?.index ?? 0).toString());
                        } catch (e) {
                          systemBean = SystemBean(version: "2.10.13", fromAutoGet: false);
                        }
                        if (!systemBean.isUpperVersion2_14_5()) {
                          "该功能仅支持v2.14.5及以上版本".toast();
                          return;
                        }
                        addFloder();
                      },
                    )
                  ],
                );
              },
              child: const Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: 15,
                ),
                child: Center(
                  child: Icon(
                    CupertinoIcons.add,
                    size: 24,
                  ),
                ),
              ),
            ),
          ],
        ),
        body: list.isEmpty
            ? const Center(
                child: LoadingWidget(),
              )
            : RefreshIndicator(
                color: Theme.of(context).primaryColor,
                onRefresh: () async {
                  await loadData();
                  return Future.value();
                },
                child: TreeView(
                  controller: _treeViewController,
                  nodeBuilder: (context, node) {
                    if (node.isParent) {
                      var theme = ref.watch(themeProvider);
                      return Container(
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        child: Row(
                          children: [
                            Icon(
                              node.expanded ? CupertinoIcons.folder_badge_minus : CupertinoIcons.folder_badge_plus,
                              size: 22,
                              color: theme.themeColor.titleColor(),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                node.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 16,
                                  color: theme.themeColor.titleColor(),
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }
                    return _buildScriptCard(context, node);
                  },
                  onExpansionChanged: (key, state) {
                    ScriptData? node = _treeViewController.getNode(key);
                    if (node != null) {
                      List<ScriptData> updated = _treeViewController.updateNode(key, node.copyWith(expanded: !node.expanded));
                      setState(() {
                        _treeViewController = _treeViewController.copyWith(children: updated);
                      });
                    }
                  },
                  onDeleteSelfClick: (ScriptData data) {
                    showCupertinoDialog(
                      useRootNavigator: false,
                      context: context,
                      builder: (context1) => CupertinoAlertDialog(
                        title: const Text("确认删除"),
                        content: const Text("确认删除吗"),
                        actions: [
                          CupertinoDialogAction(
                            child: const Text(
                              "取消",
                              style: TextStyle(
                                color: Color(0xff999999),
                              ),
                            ),
                            onPressed: () {
                              Navigator.of(context).pop();
                            },
                          ),
                          CupertinoDialogAction(
                            child: Text(
                              "确定",
                              style: TextStyle(
                                color: ref.watch(themeProvider).primaryColor,
                              ),
                            ),
                            onPressed: () async {
                              Navigator.of(context1).pop();
                              deleteFold(data);
                            },
                          ),
                        ],
                      ),
                    );
                  },
                  onNodeTap: (key) {
                    ScriptData? selectedNode = _treeViewController.getNode(key);
                    Navigator.of(context).pushNamed(
                      Routes.routeScriptDetail,
                      arguments: {
                        "title": selectedNode?.title,
                        "path": selectedNode?.parent,
                      },
                    ).then(
                      (value) {
                        if (value != null && value == true) {
                          loadData();
                        }
                      },
                    );
                  },
                ),
              ),
      ),
    );
  }

  Widget searchCell(WidgetRef context) {
    return Container(
      color: ref.watch(themeProvider).themeColor.searchBgColor(),
      padding: const EdgeInsets.symmetric(
        horizontal: 15,
        vertical: 10,
      ),
      child: SearchCell(
        controller: searchText,
      ),
    );
  }

  Future<void> loadData() async {
    HttpResponse<List<ScriptData>> response = await SingleAccountPageState.ofApi(context).scripts();

    if (response.success) {
      if (response.bean == null || response.bean!.isEmpty) {
        "暂无数据".toast();
      }
      list.clear();
      response.bean?.removeWhere((element) => element.title == "node_modules");
      list.addAll(response.bean ?? []);
      _treeViewController = TreeViewController(children: list);
      setState(() {});
      // 同步拉取定时任务，用于脚本卡片上的任务操作（运行/停止/启用/停用/定时/日志）
      try {
        HttpResponse<List<TaskBean>> taskResp = await SingleAccountPageState.ofApi(context).crons();
        if (taskResp.success && mounted) {
          setState(() {
            tasks = taskResp.bean ?? [];
          });
        }
      } catch (e) {
        tasks = [];
      }
    } else {
      response.message?.toast();
    }
  }

  @override
  void onLazyLoad() {
    loadData();
  }

  String scriptPath = "";

  void addScript() {
    Navigator.of(context)
        .push(
      CupertinoPageRoute(
        builder: (context) => const ScriptUploadPage(),
      ),
    )
        .then((value) {
      if (value != null && value == true) {
        loadData();
      }
    });
  }

  void addFloder() {
    Navigator.of(context)
        .push(
      CupertinoPageRoute(
        builder: (context) => const FloderAddPage(),
      ),
    )
        .then((value) {
      if (value != null && value == true) {
        loadData();
      }
    });
  }

  void deleteFold(ScriptData item) async {
    SystemBean? systemBean;

    try {
      systemBean = getIt<SystemBean>(instanceName: (SingleAccountPageState.of(context)?.index ?? 0).toString());
    } catch (e) {
      systemBean = SystemBean(version: "2.10.13", fromAutoGet: false);
    }
    if ((item.children.isNotEmpty) && !systemBean.isUpperVersion2_14_5()) {
      "该功能仅支持v2.14.5及以上版本".toast();
      return;
    }

    EasyLoading.show(status: "删除中...");
    var temp = (item.type == "directory")
        ? await SingleAccountPageState.ofApi(context).delScriptFold(
            item.title,
            item.parent,
          )
        : (systemBean.isUpperVersion2_14_5()
            ? await SingleAccountPageState.ofApi(context).delScriptNewVersion(
                item.title,
                item.parent,
              )
            : await SingleAccountPageState.ofApi(context).delScript(
                item.title,
                item.parent,
              ));
    EasyLoading.dismiss();
    if (temp.success) {
      "已删除".toast();
      await loadData();
    } else {
      temp.message.toast();
    }
  }

  // ==================== 脚本卡片与快捷操作 ====================

  /// 根据脚本文件名匹配关联的定时任务（面板任务 command 形如 "task xxx.py"）
  TaskBean? _findTask(ScriptData node) {
    for (final t in tasks) {
      if ((t.command ?? "").contains(node.title)) {
        return t;
      }
    }
    return null;
  }

  String _relPath(ScriptData node) {
    return node.parent.isEmpty ? node.title : "${node.parent}/${node.title}";
  }

  Widget _actionBtn(String label, VoidCallback onTap, {Color? color}) {
    return TextButton(
      onPressed: onTap,
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 0),
        minimumSize: const Size(36, 30),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        foregroundColor: color ?? ref.watch(themeProvider).primaryColor,
        textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w400),
      ),
      child: Text(label, maxLines: 1),
    );
  }

  Widget _buildScriptCard(BuildContext context, ScriptData node) {
    var theme = ref.watch(themeProvider);
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: theme.themeColor.bg2Color(),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: theme.themeColor.settingBordorColor(),
          width: 0.5,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  node.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: theme.themeColor.titleColor(),
                  ),
                ),
              ),
              _actionBtn("日志", () => _openLog(node)),
              _actionBtn("运行", () => _runScript(node)),
              _actionBtn("停止", () => _stopScript(node), color: const Color(0xffFB5858)),
            ],
          ),
          Divider(
            height: 1,
            thickness: 0.5,
            color: theme.themeColor.settingBordorColor(),
          ),
          Row(
            children: [
              Expanded(
                child: Wrap(
                  spacing: 2,
                  runSpacing: 0,
                  children: [
                    _actionBtn("启用", () => _toggleTask(node, true)),
                    _actionBtn("停用", () => _toggleTask(node, false)),
                    _actionBtn("编辑", () => _openScriptDetail(node)),
                    _actionBtn("定时", () => _openSchedule(node)),
                    _actionBtn("修改", () => _openRename(node)),
                    _actionBtn("依赖", () => _openDependency()),
                    _actionBtn("刷新", () => _refreshList()),
                    _actionBtn("环境变量", () => _openEnv(node)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _openLog(ScriptData node) {
    Navigator.of(context).pushNamed(
      Routes.routeTaskLog,
      arguments: {"search": node.title},
    );
  }

  void _runScript(ScriptData node) {
    TaskBean? task = _findTask(node);
    if (task == null || (task.sId == null && task.id == null)) {
      showCupertinoDialog(
        context: context,
        useRootNavigator: false,
        builder: (context1) => CupertinoAlertDialog(
          title: const Text("提示"),
          content: Text("脚本 ${node.title} 尚未关联定时任务，运行需要先创建定时任务。"),
          actions: [
            CupertinoDialogAction(
              child: const Text("取消"),
              onPressed: () => Navigator.of(context1).pop(),
            ),
            CupertinoDialogAction(
              child: const Text("去创建"),
              onPressed: () {
                Navigator.of(context1).pop();
                _openSchedule(node);
              },
            ),
          ],
        ),
      );
      return;
    }
    EasyLoading.show(status: "提交中...");
    _runCron([task.sId ?? "${task.id}"], "已提交运行");
  }

  void _runCron(List<String> ids, String successMsg) async {
    HttpResponse<NullResponse> response = await SingleAccountPageState.ofApi(context).startTasks(ids);
    EasyLoading.dismiss();
    if (response.success) {
      successMsg.toast();
    } else {
      "运行失败：${response.message}".toast();
    }
  }

  void _stopScript(ScriptData node) {
    TaskBean? task = _findTask(node);
    if (task == null || (task.sId == null && task.id == null)) {
      "该脚本未关联定时任务".toast();
      return;
    }
    EasyLoading.show(status: "提交中...");
    _stopCron([task.sId ?? "${task.id}"]);
  }

  void _stopCron(List<String> ids) async {
    HttpResponse<NullResponse> response = await SingleAccountPageState.ofApi(context).stopTasks(ids);
    EasyLoading.dismiss();
    if (response.success) {
      "已停止".toast();
    } else {
      "停止失败：${response.message}".toast();
    }
  }

  void _toggleTask(ScriptData node, bool enable) async {
    TaskBean? task = _findTask(node);
    if (task == null || (task.sId == null && task.id == null)) {
      "该脚本未关联定时任务".toast();
      return;
    }
    EasyLoading.show(status: "提交中...");
    List<String> ids = [task.sId ?? "${task.id}"];
    HttpResponse<NullResponse> response =
        enable ? await SingleAccountPageState.ofApi(context).enableTask(ids) : await SingleAccountPageState.ofApi(context).disableTask(ids);
    EasyLoading.dismiss();
    if (response.success) {
      enable ? "已启用".toast() : "已停用".toast();
    } else {
      "操作失败：${response.message}".toast();
    }
  }

  void _openScriptDetail(ScriptData node) {
    Navigator.of(context).pushNamed(
      Routes.routeScriptDetail,
      arguments: {
        "title": node.title,
        "path": node.parent,
      },
    ).then((value) {
      if (value != null && value == true) {
        loadData();
      }
    });
  }

  void _openSchedule(ScriptData node) {
    TaskBean? task = _findTask(node);
    Navigator.of(context)
        .push(
      CupertinoPageRoute(
        builder: (context) => AddTaskPage(
          taskBean: task ??
              (TaskBean()
                ..name = node.title
                ..command = "task ${_relPath(node)}"
                ..schedule = ""),
          hideUploadFile: true,
        ),
      ),
    )
        .then((value) {
      loadData();
    });
  }

  void _openRename(ScriptData node) {
    TaskBean? task = _findTask(node);
    TextEditingController taskNameController = TextEditingController(text: task?.name ?? node.title);
    TextEditingController scriptNameController = TextEditingController(text: node.title);
    showCupertinoDialog(
      context: context,
      useRootNavigator: false,
      builder: (context1) => CupertinoAlertDialog(
        title: const Text("修改名称"),
        content: Padding(
          padding: const EdgeInsets.only(top: 10),
          child: Column(
            children: [
              CupertinoTextField(
                controller: taskNameController,
                placeholder: "任务名称（未关联任务则不生效）",
              ),
              const SizedBox(height: 8),
              CupertinoTextField(
                controller: scriptNameController,
                placeholder: "脚本名称",
              ),
            ],
          ),
        ),
        actions: [
          CupertinoDialogAction(
            child: const Text("取消"),
            onPressed: () => Navigator.of(context1).pop(),
          ),
          CupertinoDialogAction(
            child: const Text("确定"),
            onPressed: () async {
              String newScriptName = scriptNameController.text.trim();
              if (newScriptName.isEmpty) {
                "脚本名称不能为空".toast();
                return;
              }
              Navigator.of(context1).pop();
              EasyLoading.show(status: "提交中...");
              if (newScriptName != node.title) {
                HttpResponse<NullResponse> resp =
                    await SingleAccountPageState.ofApi(context).renameScript(node.title, node.parent, newScriptName);
                if (!resp.success) {
                  EasyLoading.dismiss();
                  "脚本改名失败：${resp.message}".toast();
                  return;
                }
              }
              // 同步更新关联任务的名称与命令中的脚本文件名
              if (task != null && task.sId != null) {
                String newCommand = (task.command ?? "").replaceAll(node.title, newScriptName);
                String newTaskName = taskNameController.text.trim();
                if (newTaskName != task.name || newCommand != task.command) {
                  HttpResponse<NullResponse> resp = await SingleAccountPageState.ofApi(context).addTask(
                    newTaskName,
                    newCommand,
                    task.schedule ?? "",
                    id: task.id,
                    nId: task.sId,
                  );
                  if (!resp.success) {
                    "脚本已改名，但任务更新失败：${resp.message}".toast();
                  }
                }
              }
              EasyLoading.dismiss();
              "修改成功".toast();
              loadData();
            },
          ),
        ],
      ),
    );
  }

  void _openDependency() {
    Navigator.of(context).pushNamed(Routes.routeDependency);
  }

  void _refreshList() async {
    await loadData();
    "已刷新".toast();
  }

  void _openEnv(ScriptData node) {
    Navigator.of(context).push(
      CupertinoPageRoute(
        builder: (context) => ScriptEnvPage(scriptName: node.title),
      ),
    );
  }
}
