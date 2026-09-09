# このフォルダ専用のGitHub設定

このプロジェクトでは `./script/gh-local.sh` を使い、GitHub CLIの設定と認証情報をこのリポジトリの `.git/gh-local-auth/` に保存します。グローバルのGit設定や通常の `gh` のアカウントを切り替えません。継承したトークン・ホスト・リポジトリの環境変数を除外し、フォルダ内にトークンがなければキーチェーンへフォールバックせず停止します。

```sh
./script/gh-local.sh auth login --hostname github.com --git-protocol https --web
./script/gh-local.sh api user --jq .login
```

ブラウザで使用したいアカウントを選んで認証してください。「Gitの認証も設定するか」と聞かれた場合は、この段階では **No** を選びます。`gh auth setup-git` は使いません。Gitの作者情報とcredential helperは、アカウント確認後に `git config --local` で設定します。

ラッパーはログイン時に `--insecure-storage` を付け、キーチェーンではなくこのフォルダ内へトークンを平文保存します。ディレクトリの権限は700、作成時のumaskは077です。`.git/` 内なのでコミットされませんが、フォルダの丸ごとのコピーやバックアップには含まれます。認証トークンをREADMEやチャットへ貼らないでください。

これはアカウント設定の使い分けであり、「別フォルダや別プログラムからこのアカウントを使えない」というOSのアクセス制限ではありません。GitHubのリポジトリ権限も別の設定です。

Gitの作者名・GitHub noreplyメール・認証ユーザーは、新しくログインしたアカウントを確認してから `.git/config` へ設定します。credential helperはこのフォルダ専用CLIを呼びます。GitHub CLIを直接使う場合は `gh` ではなく `./script/gh-local.sh` を使ってください。クローン先へローカル設定は引き継がれません。

この作業フォルダではデバイス認証で `yakitori-daisuki` を確認済みです。作者名・noreplyメール・認証ユーザーも同アカウントに設定しています。以前の `.git/gh-config/` は使用しません。

参照：[GitHub CLIの環境変数](https://cli.github.com/manual/gh_help_environment)、[Gitのcredential設定](https://git-scm.com/docs/gitcredentials)。
