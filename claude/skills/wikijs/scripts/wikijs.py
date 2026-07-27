#!/usr/bin/env python3
"""Thin CLI wrapper for a personal Wiki.js 2.x instance.

Page CRUD + search via GraphQL; asset upload via the undocumented /u endpoint.
Config: WIKIJS_API_URL (default http://localhost), WIKIJS_TOKEN (required).
"""

import argparse
import json
import os
import sys
from pathlib import Path

import requests

BASE_URL = os.environ.get("WIKIJS_API_URL", "http://localhost").rstrip("/")
TOKEN = os.environ.get("WIKIJS_TOKEN", "")
MAX_UPLOAD_BYTES = int(os.environ.get("WIKIJS_MAX_UPLOAD_BYTES", 5 * 1024 * 1024))
LOCALE = "en"
TIMEOUT = 30


def die(msg: str, code: int = 1):
    print(f"error: {msg}", file=sys.stderr)
    sys.exit(code)


def gql(query: str, variables: dict | None = None) -> dict:
    resp = requests.post(
        f"{BASE_URL}/graphql",
        json={"query": query, "variables": variables or {}},
        headers={"Authorization": f"Bearer {TOKEN}"},
        timeout=TIMEOUT,
    )
    if resp.status_code == 401 or resp.status_code == 403:
        die(f"auth failed (HTTP {resp.status_code}) - check WIKIJS_TOKEN")
    resp.raise_for_status()
    body = resp.json()
    if body.get("errors"):
        die("GraphQL: " + "; ".join(e.get("message", "?") for e in body["errors"]))
    return body["data"]


def check_result(rr: dict, action: str):
    if not rr.get("succeeded"):
        die(f"{action} failed: {rr.get('message', 'unknown error')}")


def resolve_page_id(ref: str) -> int:
    """Accept numeric id or page path; return numeric id."""
    if ref.isdigit():
        return int(ref)
    data = gql(
        """query($path: String!, $locale: String!) {
             pages { singleByPath(path: $path, locale: $locale) { id } } }""",
        {"path": ref.strip("/"), "locale": LOCALE},
    )
    page = data["pages"]["singleByPath"]
    if not page:
        die(f"page not found: {ref}")
    return page["id"]


def read_content_arg(text: str | None, file: str | None) -> str | None:
    if text is not None:
        return text
    if file is not None:
        return Path(file).read_text()
    return None


# ---------- commands ----------

def cmd_create(args):
    content = read_content_arg(args.content, args.content_file) or ""
    tags = [t.strip() for t in args.tags.split(",")] if args.tags else []
    data = gql(
        """mutation($path: String!, $title: String!, $content: String!, $tags: [String]!,
                    $desc: String!, $locale: String!) {
             pages { create(path: $path, title: $title, content: $content,
                            editor: "markdown", locale: $locale, isPublished: true,
                            isPrivate: false, tags: $tags, description: $desc) {
               responseResult { succeeded message } page { id path } } } }""",
        {"path": args.path.strip("/"), "title": args.title, "content": content,
         "tags": tags, "desc": args.description, "locale": LOCALE},
    )
    result = data["pages"]["create"]
    check_result(result["responseResult"], "create")
    page = result["page"]
    print(f"created id={page['id']} path=/{page['path']}")


def cmd_update(args):
    page_id = resolve_page_id(args.ref)
    replace = read_content_arg(args.replace, args.replace_file)
    append = read_content_arg(args.append, args.append_file)
    if (replace is None) == (append is None):
        die("pass exactly one of --replace/--replace-file/--append/--append-file")
    # Wiki.js's update resolver maps over tags server-side; omitting them fails
    # with "Cannot read properties of undefined (reading 'map')". Fetch and
    # pass the existing tags back.
    data = gql(
        "query($id: Int!) { pages { single(id: $id) { content tags { tag } } } }",
        {"id": page_id},
    )
    page = data["pages"]["single"]
    if not page:
        die(f"page id {page_id} not found")
    tags = [t["tag"] for t in page.get("tags") or []]
    if append is not None:
        content = page["content"].rstrip("\n") + "\n\n" + append.rstrip("\n") + "\n"
    else:
        content = replace
    data = gql(
        """mutation($id: Int!, $content: String!, $tags: [String]!) {
             pages { update(id: $id, content: $content, tags: $tags,
                            editor: "markdown", isPublished: true) {
               responseResult { succeeded message } } } }""",
        {"id": page_id, "content": content, "tags": tags},
    )
    check_result(data["pages"]["update"]["responseResult"], "update")
    print(f"updated id={page_id}")


def cmd_get(args):
    fields = "id path title description tags { tag } updatedAt content"
    if args.ref.isdigit():
        data = gql(
            f"query($id: Int!) {{ pages {{ single(id: $id) {{ {fields} }} }} }}",
            {"id": int(args.ref)},
        )
        page = data["pages"]["single"]
    else:
        data = gql(
            f"""query($path: String!, $locale: String!) {{
                  pages {{ singleByPath(path: $path, locale: $locale) {{ {fields} }} }} }}""",
            {"path": args.ref.strip("/"), "locale": LOCALE},
        )
        page = data["pages"]["singleByPath"]
    if not page:
        die(f"page not found: {args.ref}")
    meta = {k: page[k] for k in ("id", "path", "title", "description", "updatedAt")}
    meta["tags"] = [t["tag"] for t in page.get("tags") or []]
    print(json.dumps(meta), file=sys.stderr)
    print(page["content"])


def cmd_search(args):
    data = gql(
        """query($q: String!) {
             pages { search(query: $q) { results { id title path } totalHits } } }""",
        {"q": args.query},
    )
    res = data["pages"]["search"]
    for r in res["results"]:
        print(f"{r['id']}\t/{r['path']}\t{r['title']}")
    if not res["results"]:
        print("no results", file=sys.stderr)


def cmd_list(args):
    data = gql(
        """query { pages { list(orderBy: UPDATED, orderByDirection: DESC) {
             id path title updatedAt } } }"""
    )
    for p in data["pages"]["list"][: args.limit]:
        print(f"{p['id']}\t/{p['path']}\t{p['title']}\t{p['updatedAt']}")


def cmd_delete(args):
    if not args.yes:
        die("refusing to delete without --yes")
    page_id = resolve_page_id(args.ref)
    data = gql(
        """mutation($id: Int!) { pages { delete(id: $id) {
             responseResult { succeeded message } } } }""",
        {"id": page_id},
    )
    check_result(data["pages"]["delete"]["responseResult"], "delete")
    print(f"deleted id={page_id}")


def cmd_move(args):
    page_id = resolve_page_id(args.ref)
    data = gql(
        """mutation($id: Int!, $destinationPath: String!, $destinationLocale: String!) {
             pages { move(id: $id, destinationPath: $destinationPath,
                          destinationLocale: $destinationLocale) {
               responseResult { succeeded message } } } }""",
        {"id": page_id, "destinationPath": args.destination.strip("/"),
         "destinationLocale": LOCALE},
    )
    check_result(data["pages"]["move"]["responseResult"], "move")
    print(f"moved id={page_id} -> /{args.destination.strip('/')}")


def list_folders() -> list[dict]:
    data = gql(
        """query { assets { folders(parentFolderId: 0) { id name slug } } }"""
    )
    return data["assets"]["folders"]


def cmd_folders(_args):
    print("0\t(root)\t(root)")
    for f in list_folders():
        print(f"{f['id']}\t{f['slug']}\t{f['name']}")


def resolve_folder(ref: str | None) -> tuple[int, str]:
    """Accept folder slug or numeric id (None = root); return (id, slug)."""
    if not ref:
        return 0, ""
    if ref.isdigit():
        fid = int(ref)
        slug = next((f["slug"] for f in list_folders() if f["id"] == fid), "")
        return fid, slug
    match = next((f for f in list_folders() if f["slug"] == ref), None)
    if not match:
        slugs = ", ".join(f["slug"] for f in list_folders()) or "(none)"
        die(f"no asset folder with slug '{ref}'; have: {slugs}")
    return match["id"], match["slug"]


def cmd_assets(args):
    folder_id, _ = resolve_folder(args.folder)
    data = gql(
        """query($folderId: Int!) { assets { list(folderId: $folderId, kind: ALL) {
             id filename fileSize updatedAt } } }""",
        {"folderId": folder_id},
    )
    for a in data["assets"]["list"]:
        print(f"{a['id']}\t{a['filename']}\t{a['fileSize']}\t{a['updatedAt']}")


def cmd_delete_asset(args):
    if not args.yes:
        die("refusing to delete without --yes")
    data = gql(
        """mutation($id: Int!) { assets { deleteAsset(id: $id) {
             responseResult { succeeded message } } } }""",
        {"id": args.id},
    )
    check_result(data["assets"]["deleteAsset"]["responseResult"], "delete-asset")
    print(f"deleted asset id={args.id}")


def cmd_rename_asset(args):
    data = gql(
        """mutation($id: Int!, $filename: String!) {
             assets { renameAsset(id: $id, filename: $filename) {
               responseResult { succeeded message } } } }""",
        {"id": args.id, "filename": args.filename},
    )
    check_result(data["assets"]["renameAsset"]["responseResult"], "rename-asset")
    print(f"renamed asset id={args.id} -> {args.filename}")


def cmd_upload(args):
    path = Path(args.file)
    if not path.is_file():
        die(f"file not found: {path}")
    size = path.stat().st_size
    if size > MAX_UPLOAD_BYTES:
        die(f"file is {size} bytes; exceeds limit of {MAX_UPLOAD_BYTES} "
            f"(Wiki.js default cap is 5 MB; raise server-side + WIKIJS_MAX_UPLOAD_BYTES)")

    folder_id, folder_slug = resolve_folder(args.folder)

    # Two multipart parts, both named mediaUpload: JSON metadata first, then the
    # file. Wiki.js's multer route tells them apart by filename presence.
    with path.open("rb") as fh:
        resp = requests.post(
            f"{BASE_URL}/u",
            headers={"Authorization": f"Bearer {TOKEN}"},
            files=[
                ("mediaUpload", (None, json.dumps({"folderId": folder_id}), "text/plain")),
                ("mediaUpload", (path.name, fh)),
            ],
            timeout=120,
        )
    if resp.status_code != 200:
        die(f"upload failed (HTTP {resp.status_code}): {resp.text[:300]}")
    # Wiki.js normalizes stored filenames to lowercase.
    asset_path = f"/{folder_slug}/{path.name.lower()}" if folder_slug else f"/{path.name.lower()}"
    print(asset_path)


def main():
    if not TOKEN:
        die("WIKIJS_TOKEN not set (WIKIJS_API_URL optional, default http://localhost)")

    parser = argparse.ArgumentParser(prog="wikijs.py", description=__doc__)
    sub = parser.add_subparsers(dest="cmd", required=True)

    p = sub.add_parser("create", help="create a page")
    p.add_argument("path")
    p.add_argument("title")
    p.add_argument("--content")
    p.add_argument("--content-file")
    p.add_argument("--tags", help="comma-separated")
    p.add_argument("--description", default="")
    p.set_defaults(func=cmd_create)

    p = sub.add_parser("update", help="replace or append page content")
    p.add_argument("ref", help="page path or numeric id")
    p.add_argument("--replace")
    p.add_argument("--replace-file")
    p.add_argument("--append")
    p.add_argument("--append-file")
    p.set_defaults(func=cmd_update)

    p = sub.add_parser("get", help="print page content (metadata JSON on stderr)")
    p.add_argument("ref", help="page path or numeric id")
    p.set_defaults(func=cmd_get)

    p = sub.add_parser("search", help="search pages")
    p.add_argument("query")
    p.set_defaults(func=cmd_search)

    p = sub.add_parser("list", help="list pages by last update")
    p.add_argument("--limit", type=int, default=25)
    p.set_defaults(func=cmd_list)

    p = sub.add_parser("delete", help="delete a page (requires --yes)")
    p.add_argument("ref", help="page path or numeric id")
    p.add_argument("--yes", action="store_true")
    p.set_defaults(func=cmd_delete)

    p = sub.add_parser("move", help="move/rename a page (changes its path)")
    p.add_argument("ref", help="page path or numeric id")
    p.add_argument("destination", help="new page path")
    p.set_defaults(func=cmd_move)

    p = sub.add_parser("upload", help="upload an asset; prints its embed path")
    p.add_argument("file")
    p.add_argument("--folder", help="asset folder slug or id (default: root)")
    p.set_defaults(func=cmd_upload)

    p = sub.add_parser("folders", help="list asset folders")
    p.set_defaults(func=cmd_folders)

    p = sub.add_parser("assets", help="list assets in a folder")
    p.add_argument("--folder", help="folder slug or id (default: root)")
    p.set_defaults(func=cmd_assets)

    p = sub.add_parser("delete-asset", help="delete an asset by id (requires --yes)")
    p.add_argument("id", type=int)
    p.add_argument("--yes", action="store_true")
    p.set_defaults(func=cmd_delete_asset)

    p = sub.add_parser("rename-asset", help="rename an asset (filename only; no folder move API)")
    p.add_argument("id", type=int)
    p.add_argument("filename")
    p.set_defaults(func=cmd_rename_asset)

    args = parser.parse_args()
    try:
        args.func(args)
    except requests.RequestException as e:
        die(f"cannot reach Wiki.js at {BASE_URL}: {e}")


if __name__ == "__main__":
    main()
