<?
$dbfolder = "db/";
$dbname = "webdavlog.sq3";
$filefolder ="files/";

if(!file_exists($dbfolder.$dbname)) {
	$logdb = new PDO("sqlite:".$dbfolder.$dbname);
	$logdb->exec("CREATE TABLE hits(page VARCHAR(255) PRIMARY KEY, counter INTEGER)");
} else {
	$logdb = new PDO("sqlite:".$dbfolder.$dbname);
}

$file = basename($_SERVER["QUERY_STRING"]);

$filename="$filefolder$file";

if (!file_exists($filename) || !is_file($filename)) {
	header("HTTP/1.0 404 Not Found");
	header("Content-Type: text/plain");
	print "404 Not Found";
	exit;
}

$statement = $logdb->prepare("SELECT counter FROM hits WHERE page = :file");
$statement->bindParam(":file", $file);
$statement->execute();
$record = $statement->fetchAll();

if(sizeof($record) != 0) {
	$statement = $logdb->prepare("UPDATE hits SET counter = counter+1 WHERE page = :file");
	$statement->bindParam(":file", $file);
	$statement->execute();
} else {
	$statement = $logdb->prepare("INSERT INTO hits(page, counter) VALUES (:file, 1)");
	$statement->bindParam(":file", $file);
	$statement->execute();
}

$logdb = null;

header("Content-Description: File Transer");
header("Content-Type: ".mime_content_type($filename));
header("Content-Disposition: attachment; filename=".basename($filename));
header("Content-Length: ".filesize($filename));
ob_clean();
flush();
readfile($filename);
exit;
?>
