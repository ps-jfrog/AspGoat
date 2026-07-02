clear
arg="${1:-nuget}"

export JF_NAME="psazuse" JFROG_CLI_LOG_LEVEL="DEBUG" 
export JF_RT_URL="https://${JF_NAME}.jfrog.io" BUILD_NAME="aspgoat" DTS="$(date '+%Y-%m-%d-%H-%M')"

export REPO_VIRTUAL="aspgoat-virtual"   # resolve dependencies
export REPO_LOCAL="aspgoat-dev-local"   # upload artifacts (local repo, not virtual)

jf c use ${JF_NAME} 

dotnet(){
    
    export BUILD_ID="dotnet-${DTS}" PUBLISH_DIR="./bin/Release/dotnet"
    printf " BUILD_NAME: ${BUILD_NAME}       BUILD_ID: ${BUILD_ID}\n"
    set -x
    jf dotnet-config --server-id-resolve=${JF_NAME} --repo-resolve=${REPO_VIRTUAL}

    # Curation-Audit
    jf ca --format=table --threads=100

    # Audit: X-Ray & JAS
    jf audit --sast=true --sca=true --secrets=true --licenses=true --validate-secrets=true --vuln=true --format=table --extended-table=true --threads=100 --fail=false

    # .Net Restore & Publish (jf dotnet resolves deps + collects build-info; it does NOT upload)
    # DOTNET: https://docs.jfrog.com/artifactory/docs/jf-dotnet
    jf dotnet restore --build-name="${BUILD_NAME}" --build-number="${BUILD_ID}"
    jf dotnet publish -c Release -o "${PUBLISH_DIR}" --no-restore --build-name="${BUILD_NAME}" --build-number="${BUILD_ID}"

    # Upload published artifacts (jf rt upload — NOT jf dotnet — is required for artifacts).
    jf rt upload "${PUBLISH_DIR}/*" "${REPO_LOCAL}/${BUILD_NAME}/${BUILD_ID}/" --flat=false --fail-no-op --build-name="${BUILD_NAME}" --build-number="${BUILD_ID}" --module=AspGoat

    # Optional NuGet pack + upload (requires IsPackable/PackageId/Version in .csproj)
    # jf dotnet pack -c Release --output ./nupkg --build-name="${BUILD_NAME}" --build-number="${BUILD_ID}"
    # jf rt upload "./nupkg/*.nupkg" "${REPO_LOCAL}/" \
    #     --build-name="${BUILD_NAME}" --build-number="${BUILD_ID}" --module=AspGoat

    jf rt bce ${BUILD_NAME} ${BUILD_ID}
    jf rt bag ${BUILD_NAME} ${BUILD_ID}
    jf rt bp ${BUILD_NAME} ${BUILD_ID} --detailed-summary=true
    sleep 10

    jf rt search "${REPO_LOCAL}/${BUILD_NAME}/${BUILD_ID}" --limit=10


    set +x
}
nuget(){

    export BUILD_ID="nuget-${DTS}" PUBLISH_DIR="./bin/Release/nuget"
    printf " BUILD_NAME: ${BUILD_NAME}       BUILD_ID: ${BUILD_ID}\n"
    set -x
    jf nuget-config --server-id-resolve=${JF_NAME} --repo-resolve=${REPO_VIRTUAL}

    # Curation-Audit
    jf ca --format=table --threads=100

    # Audit: X-Ray & JAS: 
    jf audit --nuget --sast=true --sca=true --secrets=true --licenses=true --validate-secrets=true --vuln=true --format=table --extended-table=true --threads=100 --fail=false

    # NUGET: https://docs.jfrog.com/artifactory/docs/jf-nuget
    jf nuget restore --build-name="${BUILD_NAME}" --build-number="${BUILD_ID}"
    jf nuget publish -c Release -o "${PUBLISH_DIR}" --no-restore --build-name="${BUILD_NAME}" --build-number="${BUILD_ID}"

    jf nuget push ${PUBLISH_DIR}/*.nupkg --build-name="${BUILD_NAME}" --build-number="${BUILD_ID}"

# Upload published artifacts (jf rt upload — NOT jf dotnet — is required for artifacts).
    jf rt upload "${PUBLISH_DIR}/*" "${REPO_LOCAL}/${BUILD_NAME}/${BUILD_ID}/" --flat=false --fail-no-op --build-name="${BUILD_NAME}" --build-number="${BUILD_ID}" --module=AspGoat


    jf rt bce ${BUILD_NAME} ${BUILD_ID} 
    jf rt bag ${BUILD_NAME} ${BUILD_ID} 
    jf rt bp ${BUILD_NAME} ${BUILD_ID} --detailed-summary=true
    set +x
}


ACTION=$(printf '%s' "$arg" | tr '[:lower:]' '[:upper:]' | xargs)
echo "User Action: ${ACTION}"
case $ACTION in
    NUGET)
        nuget
        ;;
    DOTNET)
        dotnet
        ;;
esac