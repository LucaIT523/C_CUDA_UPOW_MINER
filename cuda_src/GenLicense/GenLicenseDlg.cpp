
// GenLicenseDlg.cpp : implementation file
//

#include "pch.h"
#include "framework.h"
#include "GenLicense.h"
#include "GenLicenseDlg.h"
#include "afxdialogex.h"
#include "license.h"
#include "ThemidaSDK.h"

#ifdef _DEBUG
#define new DEBUG_NEW
#endif


// CAboutDlg dialog used for App About

class CAboutDlg : public CDialogEx
{
public:
	CAboutDlg();

// Dialog Data
#ifdef AFX_DESIGN_TIME
	enum { IDD = IDD_ABOUTBOX };
#endif

	protected:
	virtual void DoDataExchange(CDataExchange* pDX);    // DDX/DDV support

// Implementation
protected:
	DECLARE_MESSAGE_MAP()
};

CAboutDlg::CAboutDlg() : CDialogEx(IDD_ABOUTBOX)
{
}

void CAboutDlg::DoDataExchange(CDataExchange* pDX)
{
	CDialogEx::DoDataExchange(pDX);
}

BEGIN_MESSAGE_MAP(CAboutDlg, CDialogEx)
END_MESSAGE_MAP()


// CGenLicenseDlg dialog



CGenLicenseDlg::CGenLicenseDlg(CWnd* pParent /*=nullptr*/)
	: CDialogEx(IDD_GENLICENSE_DIALOG, pParent)
{
	m_hIcon = AfxGetApp()->LoadIcon(IDR_MAINFRAME);
}

void CGenLicenseDlg::DoDataExchange(CDataExchange* pDX)
{
	CDialogEx::DoDataExchange(pDX);
}

BEGIN_MESSAGE_MAP(CGenLicenseDlg, CDialogEx)
	ON_WM_SYSCOMMAND()
	ON_WM_PAINT()
	ON_WM_QUERYDRAGICON()
	ON_BN_CLICKED(IDOK, &CGenLicenseDlg::OnBnClickedOk)
	ON_BN_CLICKED(IDCANCEL, &CGenLicenseDlg::OnBnClickedCancel)
END_MESSAGE_MAP()


// CGenLicenseDlg message handlers

BOOL CGenLicenseDlg::OnInitDialog()
{
	CDialogEx::OnInitDialog();

	// Add "About..." menu item to system menu.

	// IDM_ABOUTBOX must be in the system command range.
	ASSERT((IDM_ABOUTBOX & 0xFFF0) == IDM_ABOUTBOX);
	ASSERT(IDM_ABOUTBOX < 0xF000);

	CMenu* pSysMenu = GetSystemMenu(FALSE);
	if (pSysMenu != nullptr)
	{
		BOOL bNameValid;
		CString strAboutMenu;
		bNameValid = strAboutMenu.LoadString(IDS_ABOUTBOX);
		ASSERT(bNameValid);
		if (!strAboutMenu.IsEmpty())
		{
			pSysMenu->AppendMenu(MF_SEPARATOR);
			pSysMenu->AppendMenu(MF_STRING, IDM_ABOUTBOX, strAboutMenu);
		}
	}

	// Set the icon for this dialog.  The framework does this automatically
	//  when the application's main window is not a dialog
	SetIcon(m_hIcon, TRUE);			// Set big icon
	SetIcon(m_hIcon, FALSE);		// Set small icon

	// TODO: Add extra initialization here

	return TRUE;  // return TRUE  unless you set the focus to a control
}

void CGenLicenseDlg::OnSysCommand(UINT nID, LPARAM lParam)
{
	if ((nID & 0xFFF0) == IDM_ABOUTBOX)
	{
		CAboutDlg dlgAbout;
		dlgAbout.DoModal();
	}
	else
	{
		CDialogEx::OnSysCommand(nID, lParam);
	}
}

// If you add a minimize button to your dialog, you will need the code below
//  to draw the icon.  For MFC applications using the document/view model,
//  this is automatically done for you by the framework.

void CGenLicenseDlg::OnPaint()
{
	if (IsIconic())
	{
		CPaintDC dc(this); // device context for painting

		SendMessage(WM_ICONERASEBKGND, reinterpret_cast<WPARAM>(dc.GetSafeHdc()), 0);

		// Center icon in client rectangle
		int cxIcon = GetSystemMetrics(SM_CXICON);
		int cyIcon = GetSystemMetrics(SM_CYICON);
		CRect rect;
		GetClientRect(&rect);
		int x = (rect.Width() - cxIcon + 1) / 2;
		int y = (rect.Height() - cyIcon + 1) / 2;

		// Draw the icon
		dc.DrawIcon(x, y, m_hIcon);
	}
	else
	{
		CDialogEx::OnPaint();
	}
}

// The system calls this function to obtain the cursor to display while the user drags
//  the minimized window.
HCURSOR CGenLicenseDlg::OnQueryDragIcon()
{
	return static_cast<HCURSOR>(m_hIcon);
}



void CGenLicenseDlg::OnBnClickedOk()
{

	int			w_nSts = -1;
	const TCHAR szFilter[] = _T("All Files (*.*)|*.*||");
	CFileDialog dlg(TRUE, _T("License File"), NULL, OFN_HIDEREADONLY | OFN_OVERWRITEPROMPT, szFilter, this);
	if (dlg.DoModal() != IDOK){
		return;
	}
	CString sFilePath = dlg.GetPathName();

	FILE*				w_pFile = NULL;
	BYTE				w_bReadOutData[32] = { 0, };
	UPOW_LICENSE_INFO	w_stLICENSE_INFO;
	BYTE				w_bOutData[32] = { 0, };
	TCHAR				w_szFilePath[MAX_PATH] = L"";
	int					w_nReadLen = -1;

	VM_TIGER_WHITE_START

	memset(&w_stLICENSE_INFO, 0x00, sizeof(UPOW_LICENSE_INFO));
	w_pFile = _tfopen(sFilePath.GetBuffer(), L"rb");
	if (w_pFile == NULL) {
		AfxMessageBox(L"Error ... read file");
		goto L_EXIT;
	}

	w_nReadLen = fread(&w_stLICENSE_INFO, 1, sizeof(UPOW_LICENSE_INFO), w_pFile);
	if(w_nReadLen != sizeof(UPOW_LICENSE_INFO)){
		AfxMessageBox(L"Error ... read file content");
		goto L_EXIT;
	}
	fclose(w_pFile);


	w_nSts = getHashInfo(w_stLICENSE_INFO.m_bData, 32, w_bOutData);
	if (w_nSts != 0) {
		AfxMessageBox(L"Error ... setting LicenseInfo");
		goto L_EXIT;
	}
	USES_CONVERSION;
	swprintf(w_szFilePath, L"./%s.lic", A2T(w_stLICENSE_INFO.m_szDeviceHead));
	w_pFile = _tfopen(w_szFilePath, L"wb");
	if (w_pFile == NULL) {
		AfxMessageBox(L"Error ... file open");
		goto L_EXIT;
	}
	fwrite(&w_bOutData, 1, 32, w_pFile);
	fclose(w_pFile);

	AfxMessageBox(L"OK ... ");

L_EXIT:
	VM_TIGER_WHITE_END

	return;
}


void CGenLicenseDlg::OnBnClickedCancel()
{
	// TODO: Add your control notification handler code here
	CDialogEx::OnCancel();
}
