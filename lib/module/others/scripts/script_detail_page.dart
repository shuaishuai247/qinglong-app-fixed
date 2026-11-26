import 'dart:math';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qinglong_app/base/cupertino_sheet.dart';
import 'package:qinglong_app/base/http/http.dart';
import 'package:qinglong_app/base/ql_app_bar.dart';
import 'package:qinglong_app/base/routes.dart';
import 'package:qinglong_app/base/single_account_page.dart';
import 'package:qinglong_app/base/theme.dart';
import 'package:qinglong_app/base/ui/lazy_load_state.dart';
import 'package:qinglong_app/base/ui/loading_widget.dart';
import 'package:qinglong_app/base/ui/tree/models/script_data.dart';
import 'package:qinglong_app/module/env/env_bean.dart';
import 'package:qinglong_app/module/task/add_task_page.dart';
import 'package:qinglong_app/module/task/task_bean.dart';
import 'package:qinglong_app/utils/extension.dart';
import 'package:path/path.dart' as p;
import 'package:qinglong_app/utils/icloud_utils.dart';
import 'package:share_plus/share_plus.dart';

import '../../../main.dart';
import '../../code_editor/codemirror/io.dart';
import '../../code_editor/editor.dart';
import '../../config/config_detail_page.dart';
import '../../home/system_bean.dart';
import 'script_env_page.dart';
import 'script_upload_page.dart';

class ScriptDetailPage extends ConsumerStatefulWidget {
  final String title;
  final String? path;

  const ScriptDetailPage({
    Key? key,
    required this.title,
    this.path,
  }) : super(key: key);

  @override
  _ScriptDetailPageState createState() => _ScriptDetailPageState();
}

class _ScriptDetailPageState extends ConsumerState<ScriptDetailPage> with LazyLoadState<ScriptDetailPage> {
  String? content;

  List<Widget> actions = [];

  late CodeMirrorOptions options;
  EditorController? controller;

  getLanguageType(String title) {
    if (title.endsWith(".js")) {
      return 'javascript';
    }

    if (title.endsWith(".sh")) {
      return 'shell';
    }

    if (title.endsWith(".py")) {
      return 'python';
    }
    if (title.endsWith(".json")) {
      return 'shell';
    }
    if (title.endsWith(".yaml")) {
      return 'yaml';
    }
    return "shell";
  }

  @override
  void initState() {
    options = CodeMirrorOptions(
      readOnly: true,
      mode: getLanguageType(widget.title),
    );
    super.initState();
    actions.addAll(
      [
        CupertinoSheer(
          title: "环境变量",
          onTap: () {
            Navigator.of(context).push(
              CupertinoPageRoute(
                builder: (context) => ScriptEnvPage(
                  scriptName: widget.title,
                ),
              ),
            );
          },
        ),
        addDivider(),
        CupertinoSheer(
          title: "复制脚本",
          onTap: _copyScript,
        ),
        addDivider(),
        CupertinoSheer(
          title: "添加到任务",
          onTap: () {
            if (content == null || content!.isEmpty) {
              "未获取到脚本内容,请稍候重试".toast();
              return;
            }
            String command = "task ${widget.path}${(widget.path != null && widget.path!.isNotEmpty) ? p.separator : ""}${widget.title} ";
            String? cron = ScriptUploadPageState.getCronString(content!, widget.title);

            Navigator.of(context).push(
              CupertinoPageRoute(
                builder: (context) => AddTaskPage(
                  taskBean: TaskBean(
                    name: widget.title,
                    command: command,
                    schedule: cron,
                  ),
                  hideUploadFile: true,
                ),
              ),
            );
          },
        ),
        addDivider(),
        CupertinoSheer(
          title: "编辑",
          onTap: () {
            if (content == null || content!.isEmpty) {
              "未获取到脚本内容,请稍候重试".toast();
              return;
            }
            Navigator.of(context).pushNamed(
              Routes.routeScriptUpdate,
              arguments: {
                "title": widget.title,
                "path": widget.path,
                "content": content,
              },
            ).then((value) {
              if (value != null) {
                content = value.toString();
                controller?.setValue(content ?? "");
                setState(() {});
              }
            });
          },
        ),
        addDivider(),
        CupertinoSheer(
          title: "分享",
          onTap: () {
            Share.share(content ?? "");
          },
        ),
        addDivider(),
        CupertinoSheer(
          title: "下载",
          onTap: () async {
            try {
              String name = "${Random().nextInt(40000)}_${widget.title}";
              var file = await FileUtil(0).writeDownloadFile(name, content ?? "");
              "已写入qinglong_app文件夹下,文件名$name".toast2();
            } catch (e) {
              e.toString().toast();
            }
          },
        ),
        addDivider(),
        CupertinoSheer(
          title: "删除",
          onTap: () async {
            HapticFeedback.mediumImpact();
            showCupertinoDialog(
              useRootNavigator: false,
              context: context,
              builder: (context1) => CupertinoAlertDialog(
                title: const Text("确认删除"),
                content: const Text("确认删除该脚本吗"),
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
                      SystemBean? systemBean;

                      try {
                        systemBean = getIt<SystemBean>(instanceName: (SingleAccountPageState.of(context)?.index ?? 0).toString());
                      } catch (e) {
                        systemBean = SystemBean(version: "2.10.13", fromAutoGet: false);
                      }
                      HttpResponse<NullResponse> result;
                      if (systemBean.isUpperVersion2_14_5()) {
                        result = await SingleAccountPageState.ofApi(context).delScriptNewVersion(widget.title, widget.path ?? "");
                      } else {
                        result = await SingleAccountPageState.ofApi(context).delScript(widget.title, widget.path ?? "");
                      }
                      if (result.success) {
                        "删除成功".toast();
                        Navigator.of(context).pop(true);
                      } else {
                        result.message?.toast();
                      }
                    },
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }

  @override
  void dispose() {
    EasyLoading.dismiss();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ref.watch(themeProvider).themeColor.codeBgColor(),
      appBar: QlAppBar(
        canBack: true,
        backCall: () {
          Navigator.of(context).pop();
        },
        title: widget.title,
        actions: [
          CupertinoButton(
            color: Colors.transparent,
            padding: EdgeInsets.zero,
            onPressed: () async {
              codeKey.currentState?.showSearchBar();
            },
            child: Padding(
              padding: const EdgeInsets.only(
                left: 15,
              ),
              child: Center(
                child: Icon(
                  Icons.search,
                  color: Theme.of(context).appBarTheme.iconTheme?.color,
                  size: 22,
                ),
              ),
            ),
          ),
          CupertinoButton(
            color: Colors.transparent,
            padding: EdgeInsets.zero,
            onPressed: () async {
              await hideKeyboardFocus();
              showMoreOperate(context, actions);
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 15,
              ),
              child: Center(
                child: Icon(
                  Icons.more_horiz,
                  size: 26,
                  color: Theme.of(context).appBarTheme.iconTheme?.color,
                ),
              ),
            ),
          ),
        ],
      ),
      body: content == null
          ? const Center(
              child: LoadingWidget(),
            )
          : SafeArea(
              top: false,
              child: Editor(
                options: options,
                codeMirrorKey: codeKey,
                onCreate: (val) {
                  controller = val;
                  controller?.setOptions(options);
                  controller?.setValue(content ?? "");
                },
                onValue: (val) {},
              ),
            ),
    );
  }

  GlobalKey<CodeMirrorViewState> codeKey = GlobalKey();

  Future<void> loadData() async {
    HttpResponse<String> response = await SingleAccountPageState.ofApi(context).scriptDetail(
      widget.title,
      widget.path,
    );

    if (response.success) {
      content = response.bean;
      setState(() {});
    } else {
      response.message?.toast();
    }
  }

  @override
  void onLazyLoad() {
    loadData();
  }

  // ==================== 复制脚本（多开） ====================

  /// 生成不重名的新脚本文件名：肚肚.py -> 肚肚_2.py / 肚肚_3.py ...
  String _nextScriptFileName(String title, List<String> existNames) {
    String ext = "";
    String base = title;
    int dot = title.lastIndexOf(".");
    if (dot > 0) {
      base = title.substring(0, dot);
      ext = title.substring(dot);
    }
    for (int i = 2; i < 10000; i++) {
      String candidate = "${base}_$i$ext";
      if (!existNames.contains(candidate)) {
        return candidate;
      }
    }
    return "${base}_${DateTime.now().millisecondsSinceEpoch}$ext";
  }

  /// 生成不与面板现有变量重名的新变量名
  String _nextEnvName(String name, List<EnvBean> allEnvs) {
    RegExp reg = RegExp(r"^(.+)_(\d+)$");
    String base = name;
    RegExpMatch? m = reg.firstMatch(name);
    if (m != null) {
      base = m.group(1)!;
    }
    for (int i = 2; i < 10000; i++) {
      String candidate = "${base}_$i";
      if (!allEnvs.any((e) => e.name == candidate)) {
        return candidate;
      }
    }
    return "${base}_${DateTime.now().millisecondsSinceEpoch}";
  }

  /// 复制脚本：新建脚本文件 + 代码中的变量名按自定义替换 + 复制专属环境变量（新名，备注指向新脚本）
  void _copyScript() async {
    if (content == null || content!.isEmpty) {
      "未获取到脚本内容,请稍候重试".toast();
      return;
    }
    EasyLoading.show(status: "读取中...");
    // 全量变量，用于查重与算序号
    HttpResponse<List<EnvBean>> envResp = await SingleAccountPageState.ofApi(context).envs("");
    List<EnvBean> allEnvs = envResp.success ? (envResp.bean ?? []) : [];
    // 本脚本专属变量（备注 == 脚本名）
    List<EnvBean> myEnvs = allEnvs.where((e) => e.remarks != null && e.remarks == widget.title).toList();
    // 兜底：无论备注怎么填，只要脚本代码里实际引用了这个面板变量，就纳入改名复制
    for (final e in allEnvs) {
      final n = e.name ?? "";
      if (n.isEmpty) continue;
      if (myEnvs.any((m) => m.name == n)) continue;
      if (RegExp("\\b${RegExp.escape(n)}\\b").hasMatch(content!)) {
        myEnvs.add(e);
      }
    }
    // 现有脚本文件名，用于新文件名查重
    HttpResponse<List<ScriptData>> scriptResp = await SingleAccountPageState.ofApi(context).scripts();
    List<String> existNames = [];
    if (scriptResp.success) {
      void walk(List<ScriptData> nodes) {
        for (final n in nodes) {
          if (n.isParent) {
            walk(n.children);
          } else {
            existNames.add(n.title);
          }
        }
      }
      walk(scriptResp.bean ?? []);
    }
    // 找原脚本关联的定时任务，用于预填任务名和定时规则
    HttpResponse<List<TaskBean>> cronResp = await SingleAccountPageState.ofApi(context).crons();
    TaskBean? linkedTask;
    for (final t in (cronResp.bean ?? [])) {
      if ((t.command ?? "").contains(widget.title)) {
        linkedTask = t;
        break;
      }
    }
    EasyLoading.dismiss();

    TextEditingController nameController =
        TextEditingController(text: _nextScriptFileName(widget.title, existNames));
    List<TextEditingController> envNameControllers =
        myEnvs.map((e) => TextEditingController(text: _nextEnvName(e.name ?? "", allEnvs))).toList();
    // 值默认带过来，可直接改
    List<TextEditingController> envValueControllers =
        myEnvs.map((e) => TextEditingController(text: e.value ?? "")).toList();

    bool createTask = true;
    TextEditingController taskNameController = TextEditingController(text: "");
    TextEditingController scheduleController =
        TextEditingController(text: linkedTask?.schedule ?? "");

    showCupertinoDialog(
      context: context,
      useRootNavigator: false,
      builder: (context1) => StatefulBuilder(
        builder: (context1, setDialogState) => CupertinoAlertDialog(
          title: const Text("复制脚本"),
          content: Padding(
            padding: const EdgeInsets.only(top: 10),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("新脚本名称：",
                      style: TextStyle(fontSize: 12, color: Color(0xff999999))),
                  CupertinoTextField(
                    controller: nameController,
                    onChanged: (v) {
                      if (createTask && taskNameController.text == "") {
                        setDialogState(() {});
                      }
                    },
                  ),
                  if (myEnvs.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    const Text("检测到脚本用到以下变量，新变量名/值均可自定义：",
                        style: TextStyle(fontSize: 12, color: Color(0xff999999))),
                    SizedBox(
                      height: myEnvs.length > 2 ? 240 : null,
                      child: SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            for (int i = 0; i < myEnvs.length; i++) ...[
                              const SizedBox(height: 6),
                              Text("${myEnvs[i].name}  →  新变量名：",
                                  style: const TextStyle(fontSize: 12, color: Color(0xff666666))),
                              CupertinoTextField(controller: envNameControllers[i], placeholder: "新变量名"),
                              const SizedBox(height: 4),
                              const Text("值（默认带过来，可改）：",
                                  style: TextStyle(fontSize: 11, color: Color(0xff999999))),
                              CupertinoTextField(
                                controller: envValueControllers[i],
                                placeholder: "变量值",
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ] else ...[
                    const SizedBox(height: 10),
                    const Text("未检测到本脚本引用的面板变量，将只复制脚本文件。",
                        style: TextStyle(fontSize: 12, color: Color(0xff999999))),
                  ],
                  const SizedBox(height: 8),
                  const Text(
                    "代码中出现的原变量名会自动替换为新变量名，原脚本不变。",
                    style: TextStyle(fontSize: 11, color: Color(0xff999999)),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      SizedBox(
                        height: 26,
                        child: CupertinoSwitch(
                          value: createTask,
                          onChanged: (v) {
                            setDialogState(() {
                              createTask = v;
                            });
                          },
                        ),
                      ),
                      const SizedBox(width: 6),
                      const Text("自动创建定时任务",
                          style: TextStyle(fontSize: 13, color: Color(0xff333333))),
                    ],
                  ),
                  if (createTask) ...[
                    const SizedBox(height: 6),
                    CupertinoTextField(
                      controller: taskNameController,
                      placeholder: "任务名称（默认为新脚本名）",
                    ),
                    const SizedBox(height: 6),
                    CupertinoTextField(
                      controller: scheduleController,
                      placeholder: "定时规则，如 0 8 * * *（留空=一次性任务，手动运行）",
                    ),
                  ],
                ],
              ),
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
              String newName = nameController.text.trim();
              if (newName.isEmpty) {
                "请输入新脚本名称".toast();
                return;
              }
              if (existNames.contains(newName)) {
                "脚本 $newName 已存在，请换一个名字".toast();
                return;
              }
              // 校验变量映射
              List<String> newEnvNames = [];
              for (int i = 0; i < myEnvs.length; i++) {
                String n = envNameControllers[i].text.trim();
                if (n.isEmpty) {
                  "请为变量 ${myEnvs[i].name} 填写新变量名".toast();
                  return;
                }
                if (n == myEnvs[i].name) {
                  "新变量名不能与原变量名 ${myEnvs[i].name} 相同".toast();
                  return;
                }
                if (allEnvs.any((e) => e.name == n)) {
                  "变量名 $n 已存在，请换一个".toast();
                  return;
                }
                if (newEnvNames.contains(n)) {
                  "新变量名 $n 重复了，请换一个".toast();
                  return;
                }
                newEnvNames.add(n);
              }
              // 校验定时规则：留空=一次性任务；否则须是 5 段式 cron
              String cronInput = scheduleController.text.trim();
              if (cronInput.isNotEmpty && !cronInput.startsWith("once") && !cronInput.startsWith("boot")) {
                List<String> parts = cronInput.split(RegExp(r"\s+"));
                if (parts.length != 5) {
                  "定时规则格式不对，应为 5 段式 cron（如 0 8 * * *），或留空创建一次性任务".toast();
                  return;
                }
              }
              Navigator.of(context1).pop();
              EasyLoading.show(status: "复制中...");
              // 1. 代码替换：整词替换旧变量名 -> 新变量名
              String newContent = content!;
              for (int i = 0; i < myEnvs.length; i++) {
                RegExp reg = RegExp("\\b${RegExp.escape(myEnvs[i].name ?? "")}\\b");
                newContent = newContent.replaceAllMapped(reg, (m) => newEnvNames[i]);
              }
              // 2. 新建脚本文件
              HttpResponse<NullResponse> addResp = await SingleAccountPageState.ofApi(context)
                  .addScript(newName, widget.path ?? "", newContent);
              if (!addResp.success) {
                EasyLoading.dismiss();
                "创建脚本失败：${addResp.message}".toast();
                return;
              }
              // 3. 复制变量（新名 + 弹窗里的值，备注指向新脚本）
              for (int i = 0; i < myEnvs.length; i++) {
                String val = envValueControllers[i].text;
                if (val.isEmpty) {
                  val = myEnvs[i].value ?? "";
                }
                HttpResponse<NullResponse> envAdd = await SingleAccountPageState.ofApi(context)
                    .addEnv(newEnvNames[i], val, newName);
                if (!envAdd.success) {
                  EasyLoading.dismiss();
                  "脚本已创建，但变量 ${newEnvNames[i]} 添加失败：${envAdd.message}\n请到新脚本的环境变量页手动添加"
                      .toast();
                  return;
                }
              }
              // 4. 自动创建定时任务
              if (createTask) {
                String taskName = taskNameController.text.trim();
                if (taskName.isEmpty) {
                  taskName = newName;
                }
                String relPath = (widget.path != null && widget.path!.isNotEmpty)
                    ? "${widget.path}/${newName}"
                    : newName;
                String command = "task $relPath";
                // 新版青龙定时规则必填；留空时用 "once"（一次性任务，面板里手动运行）
                String cron = scheduleController.text.trim();
                if (cron.isEmpty) {
                  cron = "once";
                }
                HttpResponse<NullResponse> taskAdd = await SingleAccountPageState.ofApi(context)
                    .addTask(taskName, command, cron);
                if (!taskAdd.success) {
                  EasyLoading.dismiss();
                  "脚本和变量已创建，但定时任务创建失败：${taskAdd.message}\n请到定时任务页手动添加（命令：$command）"
                      .toast();
                  return;
                }
                EasyLoading.dismiss();
                "复制完成：已生成 $newName 和对应定时任务".toast();
                return;
              }
              EasyLoading.dismiss();
              "复制完成，已生成 $newName".toast();
            },
          ),
        ],
      ),
      ),
    );
  }
}
