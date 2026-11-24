import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qinglong_app/base/http/http.dart';
import 'package:qinglong_app/base/ql_app_bar.dart';
import 'package:qinglong_app/base/routes.dart';
import 'package:qinglong_app/base/single_account_page.dart';
import 'package:qinglong_app/base/theme.dart';
import 'package:qinglong_app/base/ui/loading_widget.dart';
import 'package:qinglong_app/base/ui/tree/models/script_data.dart';
import 'package:qinglong_app/module/others/scripts/folder_add_page.dart';
import 'package:qinglong_app/module/others/scripts/script_env_page.dart';
import 'package:qinglong_app/module/others/scripts/script_upload_page.dart';
import 'package:qinglong_app/module/task/add_task_page.dart';
import 'package:qinglong_app/module/task/task_bean.dart';
import 'package:qinglong_app/module/task/task_page.dart';
import 'package:qinglong_app/utils/extension.dart';

import '../../../base/cupertino_sheet.dart';
import '../../../main.dart';
import '../../home/system_bean.dart';

/// 主页脚本卡片页：每个脚本一张卡片，
/// 第一行：脚本名 + 日志/运行/停止
/// 第二行：启用/停用/编辑/定时/修改/依赖/刷新/环境变量
class HomeScriptPage extends ConsumerStatefulWidget {
  const HomeScriptPage({Key? key}) : super(key: key);

  @override
  HomeScriptPageState createState() => HomeScriptPageState();
}

class HomeScriptPageState extends ConsumerState<HomeScriptPage> {
  List<ScriptData> files = [];
  List<TaskBean> tasks = [];
  bool loading = true;
  bool loadError = false;

  ScrollController controller = ScrollController();

  void move2Top() {
    if (controller.hasClients) {
      controller.animateTo(0, duration: const Duration(milliseconds: 200), curve: Curves.linear);
    }
  }

  /// 等待登录/系统信息初始化完成（SystemBean 注册成功），最多等 15 秒
  Future<void> _waitReady() async {
    for (int i = 0; i < 30; i++) {
      try {
        getIt<SystemBean>(instanceName: (SingleAccountPageState.of(context)?.index ?? 0).toString());
        return;
      } catch (e) {
        await Future.delayed(const Duration(milliseconds: 500));
      }
    }
  }

  Future<void> load() async {
    try {
      await _waitReady();
      HttpResponse<List<ScriptData>> response = await SingleAccountPageState.ofApi(context).scripts();
      if (response.success) {
        // 展平脚本树，只保留文件节点
        List<ScriptData> result = [];
        void walk(List<ScriptData> nodes) {
          for (final n in nodes) {
            if (n.isParent) {
              if (n.title != "node_modules") {
                walk(n.children);
              }
            } else {
              result.add(n);
            }
          }
        }

        walk(response.bean ?? []);
        files = result;
        loadError = false;
        // 同步拉取定时任务，用于卡片上的任务操作
        try {
          HttpResponse<List<TaskBean>> taskResp = await SingleAccountPageState.ofApi(context).crons();
          if (taskResp.success) {
            tasks = taskResp.bean ?? [];
          }
        } catch (e) {
          tasks = [];
        }
      } else {
        loadError = true;
        response.message?.toast();
      }
    } catch (e) {
      loadError = true;
    } finally {
      if (mounted) {
        setState(() {
          loading = false;
        });
      }
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((timeStamp) {
      load();
    });
  }

  @override
  Widget build(BuildContext context) {
    var theme = ref.watch(themeProvider);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onPanDown: (_) {
        FocusScope.of(context).requestFocus(FocusNode());
      },
      child: Scaffold(
        appBar: QlAppBar(
          canBack: false,
          title: "脚本",
          actions: [
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {
                showMoreOperate(
                  context,
                  [
                    CupertinoSheer(
                      title: "定时任务",
                      onTap: () {
                        Navigator.of(context).push(
                          CupertinoPageRoute(
                            builder: (context) => const TaskPage(),
                          ),
                        );
                      },
                    ),
                    addDivider(),
                    CupertinoSheer(
                      title: "新增文件",
                      onTap: () {
                        Navigator.of(context)
                            .push(
                          CupertinoPageRoute(
                            builder: (context) => const ScriptUploadPage(),
                          ),
                        )
                            .then((value) {
                          if (value != null && value == true) {
                            load();
                          }
                        });
                      },
                    ),
                    addDivider(),
                    CupertinoSheer(
                      title: "新增文件夹",
                      onTap: () {
                        Navigator.of(context)
                            .push(
                          CupertinoPageRoute(
                            builder: (context) => const FloderAddPage(),
                          ),
                        )
                            .then((value) {
                          if (value != null && value == true) {
                            load();
                          }
                        });
                      },
                    ),
                  ],
                );
              },
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 15),
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
        body: loading
            ? const Center(child: LoadingWidget())
            : loadError && files.isEmpty
                ? ListView(
                    children: [
                      const SizedBox(height: 120),
                      Center(
                        child: Text(
                          "加载失败，请检查网络和面板地址",
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 14,
                            color: theme.themeColor.titleColor(),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Center(
                        child: TextButton(
                          onPressed: () {
                            setState(() {
                              loading = true;
                              loadError = false;
                            });
                            load();
                          },
                          child: const Text("点击重试"),
                        ),
                      ),
                    ],
                  )
                : RefreshIndicator(
                color: theme.primaryColor,
                onRefresh: () async {
                  await load();
                },
                child: files.isEmpty
                    ? ListView(
                        children: const [
                          SizedBox(height: 120),
                          Center(
                            child: Text(
                              "暂无脚本\n下拉刷新或点右上角\"+\"添加",
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ],
                      )
                    : ListView.builder(
                        controller: controller,
                        padding: const EdgeInsets.only(top: 8, bottom: 20),
                        itemCount: files.length,
                        itemBuilder: (context, index) {
                          return GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: () => _openScriptDetail(files[index]),
                            child: _buildScriptCard(context, files[index]),
                          );
                        },
                      ),
              ),
      ),
    );
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
    EasyLoading.show(status: "提交中...");
    _runDirect(node);
  }

  void _runDirect(ScriptData node) async {
    HttpResponse<NullResponse> response =
        await SingleAccountPageState.ofApi(context).runScriptDirect(node.title, node.parent);
    EasyLoading.dismiss();
    if (response.success) {
      "已提交运行，日志可在\"日志\"中查看".toast();
    } else {
      // 面板版本较老没有调试运行接口时，回退用关联的定时任务运行
      TaskBean? task = _findTask(node);
      if (task != null && (task.sId != null || task.id != null)) {
        EasyLoading.show(status: "提交中...");
        _runCron([task.sId ?? "${task.id}"], "已提交运行");
        return;
      }
      "运行失败：${response.message}".toast();
    }
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
    EasyLoading.show(status: "提交中...");
    _stopDirect(node);
  }

  void _stopDirect(ScriptData node) async {
    HttpResponse<NullResponse> response =
        await SingleAccountPageState.ofApi(context).stopScriptDirect(node.title, node.parent);
    EasyLoading.dismiss();
    if (response.success) {
      "已停止".toast();
    } else {
      // 回退：停关联定时任务
      TaskBean? task = _findTask(node);
      if (task != null && (task.sId != null || task.id != null)) {
        EasyLoading.show(status: "提交中...");
        _stopCron([task.sId ?? "${task.id}"]);
        return;
      }
      "停止失败：${response.message}".toast();
    }
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
        load();
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
      load();
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
              load();
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
    await load();
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
