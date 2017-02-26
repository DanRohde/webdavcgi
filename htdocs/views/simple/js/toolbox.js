/*********************************************************************
(C) ZE CMS, Humboldt-Universitaet zu Berlin
Written by Daniel Rohde <d.rohde@cms.hu-berlin.de>
**********************************************************************
This program is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.
You should have received a copy of the GNU General Public License
along with this program.  If not, see <http://www.gnu.org/licenses/>.
**********************************************************************/

initToolBox();

function initToolBox() {
	ToolBox = { 
			addMissingSlash: $.MyStringHelper.addMissingSlash,
			blockPage: $.MyPageBlocker,
			changeUri: changeUri,
			concatUri: $.MyStringHelper.concatUri,
			confirmDialog : confirmDialog,
			cookie : $.MyCookie,
			getDialog : getDialog,
			getDialogByPost: getDialogByPost,
			getFolderTreeNodesForRows : getFolderTreeNodesForRows,
			getSelectedFiles : getSelectedFiles,
			getSelectedRows : getSelectedRows,
			getURI : getURI,
			handleJSONResponse : handleJSONResponse,
			handleWindowResize : handleWindowResize,
			hidePopupMenu : hidePopupMenu,
			initPopupMenu : initPopupMenu,
			initTabs : initTabs,
			initUpload : initUpload,
			notify : notify,
			notifyError : notifyError,
			notifyInfo : notifyInfo,
			notifyWarn : notifyWarn,
			preventDefault : $.MyPreventDefault,
			preventDefaultImmediatly : $.MyPreventDefaultImmediatly,
			postAction: postAction,
			quoteWhiteSpaces: $.MyStringHelper.quoteWhiteSpaces,
			refreshFileListEntry : refreshFileListEntry,
			removeAbortDialog: removeAbortDialog,
			renderAbortDialog: renderAbortDialog,
			renderByteSize: $.MyStringHelper.renderByteSize,
			renderByteSizes: $.MyStringHelper.renderByteSizes,
			rmcookies: $.MyCookie.rmCookies,
			simpleEscape: $.MyStringHelper.simpleEscape,
			stripSlash : $.MyStringHelper.stripSlash,
			togglecookie : $.MyCookie.toggleCookie,
			toggleRowSelection : toggleRowSelection,
			uncheckSelectedRows : uncheckSelectedRows,
			updateFileList : updateFileList
	};
}