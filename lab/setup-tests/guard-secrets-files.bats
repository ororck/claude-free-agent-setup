#!/usr/bin/env bats
# Hook guard-secrets-files.sh (outils natifs Read, Grep, Glob). Code attendu : 2 = refus, 0 = passage.

HF="$HOME/.claude/hooks/guard-secrets-files.sh"

verifie() { # <attendu> <outil> <json tool_input>
  run "$HF" <<< "$(printf '{"tool_name":"%s","tool_input":%s}' "$2" "$3")"
  [ "$status" -eq "$1" ]
}

@test "refuse : Read {\"file_path\":\"/home/mohamed/lab/app/secrets/db.txt\"}" {
  verifie 2 Read '{"file_path":"/home/mohamed/lab/app/secrets/db.txt"}'
}

@test "refuse : Read {\"file_path\":\"/home/mohamed/lab/app/.env\"}" {
  verifie 2 Read '{"file_path":"/home/mohamed/lab/app/.env"}'
}

@test "refuse : Read {\"file_path\":\"/home/mohamed/.ssh/id_rsa\"}" {
  verifie 2 Read '{"file_path":"/home/mohamed/.ssh/id_rsa"}'
}

@test "refuse : Read {\"file_path\":\"certs/tls.pem\"}" {
  verifie 2 Read '{"file_path":"certs/tls.pem"}'
}

@test "refuse : Read {\"file_path\":\"terraform.tfstate\"}" {
  verifie 2 Read '{"file_path":"terraform.tfstate"}'
}

@test "refuse : Grep {\"pattern\":\"token\",\"path\":\".kube/\"}" {
  verifie 2 Grep '{"pattern":"token","path":".kube/"}'
}

@test "refuse : Grep {\"pattern\":\"token\",\"path\":\"secrets/\"}" {
  verifie 2 Grep '{"pattern":"token","path":"secrets/"}'
}

@test "refuse : Glob {\"pattern\":\"**/*.pem\"}" {
  verifie 2 Glob '{"pattern":"**/*.pem"}'
}

@test "autorise : Read {\"file_path\":\"/home/mohamed/lab/app/.env.example\"}" {
  verifie 0 Read '{"file_path":"/home/mohamed/lab/app/.env.example"}'
}

@test "autorise : Read {\"file_path\":\"README.md\"}" {
  verifie 0 Read '{"file_path":"README.md"}'
}

@test "autorise : Grep {\"pattern\":\"token\",\"path\":\"services/\"}" {
  verifie 0 Grep '{"pattern":"token","path":"services/"}'
}

@test "autorise : Glob {\"pattern\":\"**/*.yaml\"}" {
  verifie 0 Glob '{"pattern":"**/*.yaml"}'
}

@test "autorise : Read {\"file_path\":\"docs/kubeconfig.md\"}" {
  verifie 0 Read '{"file_path":"docs/kubeconfig.md"}'
}
