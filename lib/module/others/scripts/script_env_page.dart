import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qinglong_app/base/http/http.dart';
import 'package:qinglong_app/base/ql_app_bar.dart';
import 'package:qinglong_app/base/single_account_page.dart';
import 'package:qinglong_app/base/theme.dart';
import 'package:qinglong_app/module/env/env_bean.dart';
import 'package:qinglong_app/utils/extension.dart';

/// 单个脚本的专属环境变量管理页。
/// 变量归属规则：面板环境变量的备注(remarks)字段 == 脚本文件名。
/// 在此新增/编辑的变量自动写入该标记，与其他脚本的变量互不混淆。
class ScriptEnvPage extends ConsumerStatefulWidget {
  final String scriptName;

  const ScriptEnvPage({
    Key? key,
    required this.scriptName,
  }) : super(key: key);

  @override
  ConsumerState<ScriptEnvPage> createState() => _ScriptEnvPageState();
}

class _ScriptEnvPageState extends ConsumerState<ScriptEnvPage> {
  bool loading = true;
  List<EnvBean> envs = [];
  List<EnvBean> allEnvs = [];

  /// 根据面板现有变量，为 [name] 生成下一个可用序号名：
  /// TOKEN -> TOKEN_2 / TOKEN_3 ...；已带序号的 TOKEN_3 -> TOKEN_4 ...
  String _nextNumberedName(String name) {
    RegExp reg = RegExp(r'^(.+)_(\d+)$');
    String base = name;
    RegExpMatch? m = reg.firstMatch(name);
    if (m != null) {
      base = m.group(1)!;
    }
    for (int i = 2; i < 10000; i++) {
      String candidate = "${base}_$i";
      bool exists = allEnvs.any((e) => e.name == candidate);
      if (!exists) {
        return candidate;
      }
    }
    return "${base}_${DateTime.now().millisecondsSinceEpoch}";
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((timeStamp) {
      load();
    });
  }

  Future<void> load() async {
    if (envs.isEmpty) {
      setState(() {
        loading = true;
      });
    }
    HttpResponse<List<EnvBean>> response =
        await SingleAccountPageState.ofApi(context).envs("");
    if (!mounted) return;
    if (response.success && response.bean != null) {
      allEnvs = response.bean!;
      setState(() {
        envs = response.bean!
            .where((e) => e.remarks != null && e.remarks == widget.scriptName)
            .toList();
        loading = false;
      });
    } else {
      setState(() {
        loading = false;
      });
      "获取环境变量失败：${response.message}".toast();
    }
  }

  @override
  Widget build(BuildContext context) {
    var theme = ref.watch(themeProvider);
    return Scaffold(
      appBar: QlAppBar(
        canBack: true,
        title: "环境变量（${widget.scriptName}）",
        actions: [
          GestureDetector(
            onTap: () {
              addEnv(context);
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 15),
              child: Center(
                child: Text(
                  "新增",
                  style: TextStyle(
                    fontSize: 16,
                    color: theme.primaryColor,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: load,
              child: envs.isEmpty
                  ? ListView(
                      children: [
                        const SizedBox(height: 120),
                        Center(
                          child: Text(
                            "本脚本暂无专属变量\n点击右上角\"新增\"添加",
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 14,
                              color: theme.themeColor.hintColor(),
                            ),
                          ),
                        ),
                      ],
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 15, vertical: 10),
                      itemCount: envs.length,
                      itemBuilder: (context, index) {
                        return _buildEnvItem(context, envs[index]);
                      },
                    ),
            ),
    );
  }

  Widget _buildEnvItem(BuildContext context, EnvBean env) {
    var theme = ref.watch(themeProvider);
    // 青龙面板约定：status 0=已启用，1=已停用（与原版环境变量页一致）
    bool disabled = env.status == 1;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: theme.themeColor.bg2Color(),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: theme.themeColor.settingBordorColor(),
          width: 0.5,
        ),
      ),
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
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: disabled
                        ? theme.themeColor.hintColor()
                        : theme.themeColor.titleColor(),
                    decoration:
                        disabled ? TextDecoration.lineThrough : TextDecoration.none,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  env.value ?? "",
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    color: theme.themeColor.descColor(),
                  ),
                ),
                if (disabled)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      "已停用",
                      style: TextStyle(
                        fontSize: 11,
                        color: theme.themeColor.hintColor(),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            icon: Icon(
              disabled ? Icons.toggle_off_outlined : Icons.toggle_on,
              size: 28,
              color: disabled ? theme.themeColor.hintColor() : theme.primaryColor,
            ),
            tooltip: disabled ? "启用" : "停用",
            onPressed: () {
              toggleEnv(env, disabled);
            },
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            icon: Icon(
              Icons.copy_outlined,
              size: 20,
              color: theme.themeColor.descColor(),
            ),
            tooltip: "复制一份（自动加序号）",
            onPressed: () {
              copyEnv(context, env);
            },
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            icon: Icon(
              Icons.edit_outlined,
              size: 20,
              color: theme.themeColor.descColor(),
            ),
            tooltip: "编辑",
            onPressed: () {
              editEnv(context, env);
            },
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            icon: const Icon(
              Icons.delete_outline,
              size: 20,
              color: Color(0xffFB5858),
            ),
            tooltip: "删除",
            onPressed: () {
              delEnv(context, env);
            },
          ),
        ],
      ),
    );
  }

  Future<void> toggleEnv(EnvBean env, bool currentlyDisabled) async {
    EasyLoading.show(status: "提交中...");
    HttpResponse<NullResponse> response = currentlyDisabled
        ? await SingleAccountPageState.ofApi(context).enableEnv([env.sId ?? ""])
        : await SingleAccountPageState.ofApi(context)
            .disableEnv([env.sId ?? ""]);
    EasyLoading.dismiss();
    if (response.success) {
      currentlyDisabled ? "已启用".toast() : "已停用".toast();
      load();
    } else {
      "操作失败：${response.message}".toast();
    }
  }

  Future<void> delEnv(BuildContext context, EnvBean env) async {
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
                  await SingleAccountPageState.ofApi(context)
                      .delEnv(env.sId ?? env.nId);
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

  void addEnv(BuildContext context) {
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
                "归属脚本：${widget.scriptName}",
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
                widget.scriptName,
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

  /// 复制一份变量：变量名自动加序号（保证不与面板现有变量重名），值预填原值可改
  void copyEnv(BuildContext context, EnvBean env) {
    String suggestedName = _nextNumberedName(env.name ?? "");
    TextEditingController nameController =
        TextEditingController(text: suggestedName);
    TextEditingController valueController =
        TextEditingController(text: env.value ?? "");
    showCupertinoDialog(
      context: context,
      useRootNavigator: false,
      builder: (context1) => CupertinoAlertDialog(
        title: const Text("复制变量"),
        content: Padding(
          padding: const EdgeInsets.only(top: 10),
          child: Column(
            children: [
              Text(
                "原变量：${env.name ?? ""}",
                style: const TextStyle(fontSize: 12, color: Color(0xff999999)),
              ),
              const SizedBox(height: 8),
              CupertinoTextField(
                controller: nameController,
                placeholder: "新变量名（已自动加序号）",
              ),
              const SizedBox(height: 8),
              CupertinoTextField(
                controller: valueController,
                placeholder: "变量值",
              ),
              const SizedBox(height: 8),
              Text(
                "归属脚本：${widget.scriptName}",
                style: const TextStyle(fontSize: 12, color: Color(0xff999999)),
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
              String newName = nameController.text.trim();
              if (newName.isEmpty) {
                "请输入变量名".toast();
                return;
              }
              if (allEnvs.any((e) => e.name == newName)) {
                "变量名 $newName 已存在，请换一个".toast();
                return;
              }
              Navigator.of(context1).pop();
              EasyLoading.show(status: "提交中...");
              HttpResponse<NullResponse> response =
                  await SingleAccountPageState.ofApi(context).addEnv(
                newName,
                valueController.text,
                widget.scriptName,
              );
              EasyLoading.dismiss();
              if (response.success) {
                "已复制为 $newName".toast();
                load();
              } else {
                "复制失败：${response.message}".toast();
              }
            },
          ),
        ],
      ),
    );
  }

  void editEnv(BuildContext context, EnvBean env) {
    TextEditingController nameController =
        TextEditingController(text: env.name ?? "");
    TextEditingController valueController =
        TextEditingController(text: env.value ?? "");
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
                widget.scriptName,
                id: env.id,
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
}
