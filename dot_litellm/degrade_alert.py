import datetime, pathlib, sys
from litellm.integrations.custom_logger import CustomLogger

LOW = {
    "zai-glm-4.7", "cohere-command-a", "groq-gpt-oss-20b",
    "ol-gpt-oss-20b", "ol-nemotron-nano", "zai-glm-4.5", "cf-llama-3.3", "pollinations",
}
PRIMAIRES = {"worker-a", "worker-b", "worker-c", "verifier"}
LOG = pathlib.Path.home() / ".litellm" / "degraded.log"
ROUTAGE = pathlib.Path.home() / ".litellm" / "routing.log"

class DegradeAlert(CustomLogger):
    async def async_log_success_event(self, kwargs, response_obj, start_time, end_time):
        md = (kwargs.get("litellm_params") or {}).get("metadata") or {}
        group = md.get("model_group") or ""
        modele = kwargs.get("model") or ""
        now = f"{datetime.datetime.now():%Y-%m-%d %H:%M:%S}"
        # Journal de tous les appels : quel groupe a vraiment servi, avec quel modele
        statut = "PRIMAIRE" if group in PRIMAIRES else "REPLI"
        with ROUTAGE.open("a") as f:
            f.write(f"{now}  {statut:8}  {group}  {modele}\n")
        if group in LOW:
            line = f"{now}  MODELE DEGRADE : {group}\n"
            with LOG.open("a") as f:
                f.write(line)
            print(f"\033[1;31m{line.strip()}\033[0m", file=sys.stderr, flush=True)

proxy_handler_instance = DegradeAlert()
