# このフォルダ専用のGitHub設定

このプロジェクトでは `./script/gh-local.sh` を使うと、GitHub CLIの設定先をこのリポジトリの `.git/gh-config/` に分けられます。グローバルのGit設定や通常の `gh` のアカウントを切り替える必要はありません。継承したトークン・ホスト・リポジトリの環境変数はこのコマンド内で除外します。

```sh
./script/gh-local.sh auth login --hostname github.com --git-protocol https --web
./script/gh-local.sh api user --jq .login
```

ブラウザで使用したいアカウントを選んで認証してください。「Gitの認証も設定するか」と聞かれた場合は、この段階では **No** を選びます。`gh auth setup-git` は使いません。Gitの作者情報とcredential helperは、アカウント確認後に `git config --local` で設定します。

通常、認証情報はGitHub CLIがmacOSのキーチェーンに保存します。キーチェーンを利用できない場合は設定ファイルへ保存されることがあります。設定は `.git/` 内なのでコミットされません。認証トークンをREADMEやチャットへ貼らないでください。

これはアカウント設定の使い分けであり、「別フォルダや別プログラムからこのアカウントを使えない」というOSのアクセス制限ではありません。GitHubのリポジトリ権限も別の設定です。

この作業フォルダには `yakitori-daisuki` を設定しています。Gitの作者名・GitHub noreplyメール・認証ユーザー・credential helperは `.git/config` のローカル設定です。通常のGitコマンドはフォルダ専用CLIを経由して認証します。GitHub CLIを直接使う場合は `gh` ではなく `./script/gh-local.sh` を使ってください。クローン先へローカル設定は引き継がれません。

参照：[GitHub CLIの環境変数](https://cli.github.com/manual/gh_help_environment)、[Gitのcredential設定](https://git-scm.com/docs/gitcredentials)。
